--
-- (C) 2014-26 - ntop.org
--

-- ###############################################

-- See Utils::l4proto2name()
local l4_protocol_list = {}
  
l4_protocol_list.l4_keys = {
  { "TCP",       "tcp",         6 },
  { "UDP",       "udp",        17 },
  { "IP-in-IP",  "ip_in_ip",    4 },
  { "EIGRP",     "eigrp",      88 },
  { "ESP",       "esp",        50 },
  { "GRE",       "gre",        47 },
  { "HIP",       "hip",       139 },
  { "ICMP",      "icmp",        1 },
  { "ICMPv6",    "icmpv6",     58 },
  { "IGMP",      "igmp",        2 },
  { "IP",        "ip",          0 },
  { "IPv6",      "ipv6",       41 },
  { "IPv6-ICMP", "ipv6icmp",   58 },
  { "L2TP",      "l2tp",      115 },
  { "OSPF",      "ospf",       89 },
  { "PIM",       "pim",       103 },
  { "RSVP",      "rsvp",       46 },
  { "IPv6-Frag", "ipv6_frag",  44 },
  { "SCTP",      "sctp",      132 },
  { "VRRP",      "vrrp",      112 },
  { "Other IP",  "other_ip",   -1 }
}

return l4_protocol_list
