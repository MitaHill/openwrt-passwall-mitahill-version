local m, s, data = ...

if not data.node_id or not data.node then
	return
end

local current_node_id = data.node_id
local node_list = data.node_list or api.get_node_list()

local function get_cfgvalue()
	return function(self, section)
		return m:get(current_node_id, self.option)
	end
end
local function get_write()
	return function(self, section, value)
		if data.verify_option then
			if data.verify_option:formvalue(section) == current_node_id then
				m:set(current_node_id, self.option, value)
			end
		else
			m:set(current_node_id, self.option, value)
		end
	end
end
local function get_remove()
	return function(self, section)
		if data.verify_option then
			if data.verify_option:formvalue(section) == current_node_id then
				m:del(current_node_id, self.option)
			end
		else
			m:del(current_node_id, self.option)
		end
	end
end

if data.tab then
	s:tab(data.tab, data.tab_desc)
end

local function add_option(class, option_name, option_title, option_desc)
	local a
	if data.tab then
		a = s:taboption(data.tab, class, option_name, option_title)
	else
		a = s:option(class, option_name, option_title)
	end
	if a then
		if option_desc then
			a.description = option_desc
		end
		a.cfgvalue = get_cfgvalue()
		a.write = get_write()
		a.remove = get_remove()
	end
	if data.verify_option then
		a:depends(data.verify_option.option, current_node_id)
	end
	return a
end

local function add_depends(o, deps)
	if #o.deps > 0 then
		for index, value in ipairs(o.deps) do
			for k, v in pairs(deps) do
				o.deps[index][k] = v
			end
		end
	else
		o:depends(deps)
	end
end

if data.node.type == "Xray" then
	o = add_option(ListValue, "domainStrategy", translate("Domain Strategy"))
	o:value("AsIs")
	o:value("IPIfNonMatch")
	o:value("IPOnDemand")
	o.default = "IPOnDemand"
	o.description = "<br /><ul><li>" .. translate("'AsIs': Only use domain for routing. Default value.")
		.. "</li><li>" .. translate("'IPIfNonMatch': When no rule matches current domain, resolves it into IP addresses (A or AAAA records) and try all rules again.")
		.. "</li><li>" .. translate("'IPOnDemand': As long as there is a IP-based rule, resolves the domain into IP immediately.")
		.. "</li></ul>"

	o = add_option(ListValue, "domainMatcher", translate("Domain matcher"))
	o:value("hybrid")
	o:value("linear")
end

o = add_option(Flag, "fakedns", '<a style="color:#FF8C00">FakeDNS</a>' .. " " .. translate("Main switch"), translate("Use FakeDNS work in the domain that proxy.") .. "<br>" ..
	translate("Suitable scenarios for let the node servers get the target domain names.") .. "<br>" ..
	translate("Such as: DNS unlocking of streaming media, reducing DNS query latency, etc."))

local shunt_rules = {}
m.uci:foreach(appname, "shunt_rules", function(e)
	e.id = e[".name"]
	e.remarks = e.remarks or e[".name"]
	e["_node_option"] = e[".name"]
	e["_node_default"] = ""
	e["_fakedns_option"] = e[".name"] .. "_fakedns"
	e["_proxy_tag_option"] = e[".name"] .. "_proxy_tag"
	e["_dns_global_option"] = e[".name"] .. "_dns_global"
	e["_dns_protocol_option"] = e[".name"] .. "_dns_protocol"
	e["_dns_strategy_option"] = e[".name"] .. "_dns_strategy"
	e["_dns_server_option"] = e[".name"] .. "_dns_server"
	table.insert(shunt_rules, e)
end)
table.insert(shunt_rules, {
	id = ".default",
	remarks = translate("Default"),
	_node_option = "default_node",
	_node_default = "_direct",
	_fakedns_option = "default_fakedns",
	_proxy_tag_option = "default_proxy_tag",
	_dns_global_option = "default_dns_global",
	_dns_protocol_option = "default_dns_protocol",
	_dns_strategy_option = "default_dns_strategy",
	_dns_server_option = "default_dns_server",
})

s2 = m:section(Table, shunt_rules, " ")
s2.config = appname
s2.sectiontype = "shunt_option_list"

o = s2:option(DummyValue, "remarks", translate("Rule"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	if shunt_rules[section].id == ".default" then
		return string.format('<font style="color: red">%s</font>', shunt_rules[section].remarks)
	else
		return string.format('<a href="%s" target="_blank">%s</a>', api.url("shunt_rules", shunt_rules[section].id), shunt_rules[section].remarks)
	end
end

_node = s2:option(Value, "_node", translate("Node"))
_node.template = appname .. "/cbi/nodes_listvalue"
_node.group = {"","","",""}
_node:value("", translate("Close (Not use)"))
_node:value("_default", translate("Use default node"))
_node:value("_direct", translate("Direct Connection"))
_node:value("_blackhole", translate("Blackhole (Block)"))
_node.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_node_option"]) or shunt_rules[section]["_node_default"]
end
_node.write = function(self, section, value)
	return m:set(current_node_id, shunt_rules[section]["_node_option"], value)
end
_node.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_node_option"])
end

o = s2:option(Flag, "_fakedns", string.format('<a style="color:#FF8C00" title="%s">FakeDNS</a>', translate("Use FakeDNS work in the domain that proxy.") .. "\n" ..
	translate("Suitable scenarios for let the node servers get the target domain names.") .. "\n" ..
	translate("Such as: DNS unlocking of streaming media, reducing DNS query latency, etc.")))
o.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_fakedns_option"])
end
o.write = function(self, section, value)
	return m:set(current_node_id, shunt_rules[section]["_fakedns_option"], value)
end
o.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_fakedns_option"])
end

proxy_tag_node = s2:option(ListValue, "_proxy_tag", string.format('<a style="color:red" title="%s">%s</a>',
	translate("Set the node to be used as a pre-proxy.") .. "\n" .. translate("Each rule has a separate switch that controls whether this rule uses the pre-proxy or not."),
	translate("Preproxy")))
proxy_tag_node.template = appname .. "/cbi/nodes_listvalue"
proxy_tag_node.group = {""}
proxy_tag_node:value("", translate("Close (Not use)"))
proxy_tag_node.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_proxy_tag_option"])
end
proxy_tag_node.write = function(self, section, value)
	return m:set(current_node_id, shunt_rules[section]["_proxy_tag_option"], value)
end
proxy_tag_node.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_proxy_tag_option"])
end

-- 不修复时：所有分流规则只能共享全局远程 DNS，规则流量已走指定节点时，DNS 仍可能从全局出口解析。
-- 修复逻辑：在“规则/节点/FakeDNS/前置代理”同一表格内新增 DNS 列，字段保存在当前分流节点下，不改全局规则定义。
-- 预期结果：每条 Sing-Box 分流规则可继续使用全局 DNS，也可独立指定 DNS 协议、解析栈和服务器。
dns_global = s2:option(Flag, "_dns_global", "DNS<br />" .. translate("Use global config"))
dns_global.default = "1"
dns_global.rmempty = false
dns_global.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_dns_global_option"]) or "1"
end
dns_global.write = function(self, section, value)
	return m:set(current_node_id, shunt_rules[section]["_dns_global_option"], value)
end
dns_global.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_dns_global_option"])
end

dns_protocol = s2:option(ListValue, "_dns_protocol", translate("DNS Request protocol"))
dns_protocol:value("udp", "UDP")
dns_protocol:value("tcp", "TCP")
dns_protocol:value("doh", "DoH")
dns_protocol:value("http3", "HTTP3(DoH3)")
dns_protocol.default = "doh"
dns_protocol.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_dns_protocol_option"]) or "doh"
end
dns_protocol.write = function(self, section, value)
	return m:set(current_node_id, shunt_rules[section]["_dns_protocol_option"], value)
end
dns_protocol.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_dns_protocol_option"])
end

dns_strategy = s2:option(ListValue, "_dns_strategy", translate("DNS stack filter"))
dns_strategy:value("", translate("All"))
dns_strategy:value("ipv4_only", translate("IPv4 Only"))
dns_strategy:value("ipv6_only", translate("IPv6 Only"))
dns_strategy.default = ""
dns_strategy.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_dns_strategy_option"]) or ""
end
dns_strategy.write = function(self, section, value)
	if value and value ~= "" then
		return m:set(current_node_id, shunt_rules[section]["_dns_strategy_option"], value)
	end
	return m:del(current_node_id, shunt_rules[section]["_dns_strategy_option"])
end
dns_strategy.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_dns_strategy_option"])
end

dns_server = s2:option(Value, "_dns_server", translate("DNS Server"))
dns_server:value("1.1.1.1", "1.1.1.1 (CloudFlare)")
dns_server:value("1.1.1.2", "1.1.1.2 (CloudFlare-Security)")
dns_server:value("8.8.4.4", "8.8.4.4 (Google)")
dns_server:value("8.8.8.8", "8.8.8.8 (Google)")
dns_server:value("9.9.9.9", "9.9.9.9 (Quad9)")
dns_server:value("149.112.112.112", "149.112.112.112 (Quad9)")
dns_server:value("208.67.222.222", "208.67.222.222 (OpenDNS)")
dns_server:value("https://1.1.1.1/dns-query", "DoH 1.1.1.1 (CloudFlare)")
dns_server:value("https://8.8.8.8/dns-query", "DoH 8.8.8.8 (Google)")
dns_server:value("https://9.9.9.9/dns-query", "DoH 9.9.9.9 (Quad9)")
dns_server:value("https://dns.adguard.com/dns-query,94.140.14.14", "DoH AdGuard")
dns_server.default = "https://1.1.1.1/dns-query"
dns_server.cfgvalue = function(self, section)
	return m:get(current_node_id, shunt_rules[section]["_dns_server_option"]) or "https://1.1.1.1/dns-query"
end
dns_server.write = function(self, section, value)
	value = api.trim(value or "")
	if value ~= "" then
		return m:set(current_node_id, shunt_rules[section]["_dns_server_option"], value)
	end
	return m:del(current_node_id, shunt_rules[section]["_dns_server_option"])
end
dns_server.remove = function(self, section)
	return m:del(current_node_id, shunt_rules[section]["_dns_server_option"])
end

for k1, v1 in pairs(node_list) do
	if k1 ~= "shunt_list" then
		for i, v in ipairs(v1) do
			_node:value(v.id, v.remark)
			_node.group[#_node.group+1] = (v.group and v.group ~= "") and v.group or translate("default")

			proxy_tag_node:value(v.id, v.remark)
			proxy_tag_node.group[#proxy_tag_node.group+1] = (v.group and v.group ~= "") and v.group or translate("default")
		end
	end
end

local footer = Template(appname .. "/include/shunt_options")
footer.api = api
footer.id = current_node_id
footer.normal_list = api.jsonc.stringify(node_list.normal_list)
m:append(footer)
