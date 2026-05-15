local m, s, data = ...
local http = require "luci.http"

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

local function write_rule_dns_options(section)
	local rule = shunt_rules[section]
	if not rule then
		return
	end

	local prefix = "cbid.table." .. section .. "."
	local global = http.formvalue(prefix .. "_dns_global") or "1"
	local protocol = http.formvalue(prefix .. "_dns_protocol") or "doh"
	local strategy = http.formvalue(prefix .. "_dns_strategy") or ""
	local server = api.trim(http.formvalue(prefix .. "_dns_server") or "")

	m:set(current_node_id, rule["_dns_global_option"], global == "0" and "0" or "1")
	if global == "0" then
		m:set(current_node_id, rule["_dns_protocol_option"], protocol)
		if strategy ~= "" then
			m:set(current_node_id, rule["_dns_strategy_option"], strategy)
		else
			m:del(current_node_id, rule["_dns_strategy_option"])
		end
		if server ~= "" then
			m:set(current_node_id, rule["_dns_server_option"], server)
		else
			m:del(current_node_id, rule["_dns_server_option"])
		end
	else
		m:del(current_node_id, rule["_dns_protocol_option"])
		m:del(current_node_id, rule["_dns_strategy_option"])
		m:del(current_node_id, rule["_dns_server_option"])
	end
end

local old_on_before_save = m.on_before_save
m.on_before_save = function(self)
	if old_on_before_save then
		old_on_before_save(self)
	end
	for section, _ in ipairs(shunt_rules) do
		write_rule_dns_options(section)
	end
end

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

local function html_attr(value)
	return tostring(value or ""):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

dns_button = s2:option(DummyValue, "_dns", "DNS")
dns_button.rawhtml = true
dns_button.cfgvalue = function(self, section)
	local rule = shunt_rules[section]
	local global = m:get(current_node_id, rule["_dns_global_option"]) or "1"
	local protocol = m:get(current_node_id, rule["_dns_protocol_option"]) or "doh"
	local strategy = m:get(current_node_id, rule["_dns_strategy_option"]) or ""
	local server = m:get(current_node_id, rule["_dns_server_option"]) or "https://1.1.1.1/dns-query"
	local text = translate("Use global config")
	if global == "0" then
		local strategy_text = strategy == "ipv4_only" and translate("IPv4 Only") or strategy == "ipv6_only" and translate("IPv6 Only") or translate("All")
		text = string.format("%s: %s / %s", translate("Custom"), protocol:upper(), strategy_text)
	end
	return string.format(
		'<input type="button" class="btn cbi-button cbi-button-edit shunt-dns-edit" value="%s" data-section="%s" data-global="%s" data-protocol="%s" data-strategy="%s" data-server="%s" />'
		.. '<input type="hidden" id="cbid.table.%s._dns_global" name="cbid.table.%s._dns_global" value="%s" />'
		.. '<input type="hidden" id="cbid.table.%s._dns_protocol" name="cbid.table.%s._dns_protocol" value="%s" />'
		.. '<input type="hidden" id="cbid.table.%s._dns_strategy" name="cbid.table.%s._dns_strategy" value="%s" />'
		.. '<input type="hidden" id="cbid.table.%s._dns_server" name="cbid.table.%s._dns_server" value="%s" />',
		html_attr(text),
		html_attr(section),
		html_attr(global),
		html_attr(protocol),
		html_attr(strategy),
		html_attr(server),
		html_attr(section),
		html_attr(section),
		html_attr(global),
		html_attr(section),
		html_attr(section),
		html_attr(protocol),
		html_attr(section),
		html_attr(section),
		html_attr(strategy),
		html_attr(section),
		html_attr(section),
		html_attr(server)
		)
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
