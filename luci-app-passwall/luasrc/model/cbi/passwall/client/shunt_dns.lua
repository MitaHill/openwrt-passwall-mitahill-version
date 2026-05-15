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

m.description = string.format(
	'<div class="cbi-section-descr"><strong>%s</strong>: %s<br /><strong>%s</strong>: %s</div>',
	translate("Shunt Node"), html_attr(node_label),
	translate("Rule"), html_attr(rule_label)
)

m.on_before_save = function(self)
	m:set("@global[0]", "flush_set", "1")
	local global = luci.http.formvalue("cbid." .. appname .. "." .. node_id .. "." .. prefix .. "global")
	if global ~= "0" then
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

o = s:option(Value, prefix .. "server", translate("DNS Server"))
o:value("1.1.1.1", "1.1.1.1 (CloudFlare)")
o:value("1.1.1.2", "1.1.1.2 (CloudFlare-Security)")
o:value("8.8.4.4", "8.8.4.4 (Google)")
o:value("8.8.8.8", "8.8.8.8 (Google)")
o:value("9.9.9.9", "9.9.9.9 (Quad9)")
o:value("149.112.112.112", "149.112.112.112 (Quad9)")
o:value("208.67.222.222", "208.67.222.222 (OpenDNS)")
o:value("https://1.1.1.1/dns-query", "DoH 1.1.1.1 (CloudFlare)")
o:value("https://8.8.8.8/dns-query", "DoH 8.8.8.8 (Google)")
o:value("https://9.9.9.9/dns-query", "DoH 9.9.9.9 (Quad9)")
o:value("https://dns.adguard.com/dns-query,94.140.14.14", "DoH AdGuard")
o.default = "https://1.1.1.1/dns-query"
o.combobox_manual = translate("Custom")
o.description = translate("Select a preset server or enter a custom DNS server address.")
o.rmempty = true
o:depends(prefix .. "global", false)

return m
