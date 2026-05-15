local api = require "luci.passwall.api"
local appname = "passwall"

local node_id = arg[1]
local rule_id = arg[2]

m = Map(appname, translate("Shunt Rule DNS"))
m.redirect = node_id and api.url("node_config", node_id) or api.url("node_list")
api.set_apply_on_parse(m)

local node = node_id and m.uci:get_all(appname, node_id)
if not node or node.protocol ~= "_shunt" then
	luci.http.redirect(m.redirect)
end
local node_label = node.remarks or node_id

local rule_name, rule_label
if rule_id == ".default" then
	rule_name = "default"
	rule_label = translate("Default")
else
	local rule = rule_id and m.uci:get_all(appname, rule_id)
	if not rule or rule[".type"] ~= "shunt_rules" then
		luci.http.redirect(m.redirect)
	end
	rule_name = rule_id
	rule_label = rule.remarks or rule_id
end

local prefix = rule_name .. "_dns_"

local function html_attr(value)
	return tostring(value or ""):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

-- 这里仅展示当前编辑对象，避免把编辑上下文挤进表单主体。
m.description = string.format(
	'<div class="cbi-section-descr" style="padding:8px 12px;border-left:3px solid #4a90e2;background:#f7faff;line-height:1.8">' ..
		'<div><span style="display:inline-block;min-width:6em;color:#666">%s</span><strong style="font-size:1.05em">%s</strong></div>' ..
		'<div><span style="display:inline-block;min-width:6em;color:#666">%s</span><strong style="font-size:1.05em">%s</strong></div>' ..
	'</div>',
	translate("Shunt Node"), html_attr(node_label),
	translate("Rule"), html_attr(rule_label)
)

m.on_before_save = function(self)
	m:set("@global[0]", "flush_set", "1")
	local global_option = prefix .. "global"
	local global_cbid = "cbid." .. appname .. "." .. node_id .. "." .. global_option
	local global_exists = luci.http.formvalue("cbi.cbe." .. appname .. "." .. node_id .. "." .. global_option)
	local use_global
	-- LuCI Flag 未勾选时没有 cbid 值，只有 cbi.cbe 存在标记；不能把 nil 当成“使用全局”。
	if global_exists then
		use_global = luci.http.formvalue(global_cbid) ~= nil
	else
		use_global = (m:get(node_id, global_option) or "1") ~= "0"
	end
	if use_global then
		m:del(node_id, prefix .. "protocol")
		m:del(node_id, prefix .. "strategy")
		m:del(node_id, prefix .. "server")
	end
end

s = m:section(NamedSection, node_id, "nodes", translate("DNS"))
s.addremove = false
s.dynamic = false

o = s:option(Flag, prefix .. "global", translate("Use global config"))
o.default = "1"
o.rmempty = false

o = s:option(ListValue, prefix .. "protocol", translate("DNS Request protocol"))
o:value("udp", "UDP")
o:value("tcp", "TCP")
o:value("doh", "DoH")
o:value("http3", "HTTP3(DoH3)")
o.default = "doh"
o.rmempty = true
o:depends(prefix .. "global", false)

o = s:option(ListValue, prefix .. "strategy", translate("DNS response"))
o:value("", translate("All"))
o:value("ipv4_only", translate("IPv4 Only"))
o:value("ipv6_only", translate("IPv6 Only"))
o.default = ""
o.rmempty = true
o:depends(prefix .. "global", false)

local function add_server_field(option, protocols, presets, default_value)
	-- 把协议和预设列表拆开，避免在前端动态删选项后出现保存错位。
	local o = s:option(Value, prefix .. option, translate("DNS Server"))
	for _, item in ipairs(presets) do
		o:value(item[1], item[2])
	end
	o.default = default_value
	o.combobox_manual = translate("Custom")
	o.description = translate("Select a preset server or enter a custom DNS server address.")
	o.rmempty = true
	o.forcewrite = true
	o.cfgvalue = function(self, section)
		return m:get(node_id, prefix .. "server") or default_value
	end
	o.write = function(self, section, value)
		value = api.trim(value or "")
		if value ~= "" then
			return m:set(node_id, prefix .. "server", value)
		end
	end
	o.remove = function(self, section)
	end
	for _, protocol in ipairs(protocols) do
		o:depends({ [prefix .. "global"] = false, [prefix .. "protocol"] = protocol })
	end
end

add_server_field("_server_plain", { "udp", "tcp" }, {
	{ "1.1.1.1", "1.1.1.1 (CloudFlare)" },
	{ "1.1.1.2", "1.1.1.2 (CloudFlare-Security)" },
	{ "8.8.4.4", "8.8.4.4 (Google)" },
	{ "8.8.8.8", "8.8.8.8 (Google)" },
	{ "9.9.9.9", "9.9.9.9 (Quad9)" },
	{ "149.112.112.112", "149.112.112.112 (Quad9)" },
	{ "208.67.222.222", "208.67.222.222 (OpenDNS)" },
}, "1.1.1.1")

add_server_field("_server_doh", { "doh", "http3" }, {
	{ "https://1.1.1.1/dns-query", "DoH 1.1.1.1 (CloudFlare)" },
	{ "https://8.8.8.8/dns-query", "DoH 8.8.8.8 (Google)" },
	{ "https://9.9.9.9/dns-query", "DoH 9.9.9.9 (Quad9)" },
	{ "https://dns.adguard.com/dns-query,94.140.14.14", "DoH AdGuard" },
}, "https://1.1.1.1/dns-query")

return m
