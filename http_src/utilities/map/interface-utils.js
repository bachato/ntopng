/*
  (C) 2013-24 - ntop.org
 */

const interfaces = [
   { is_pcap_interface: true, icon: "<i class='fas fa-file'></i>" },
   { is_packet_interface: true, icon: "<i class='fas fa-ethernet'></i>" },
   { is_zmq_interface: true, icon: "<i class='fas fa-bezier-curve'></i>" },
   { is_view_interface: true, icon: "<i class='fas fa-eye'></i>" },
   { is_dynamic_interface: true, icon: "<i class='fas fa-code-branch'></i>" },
   { is_dropping_interface: true, icon: "<i class='fas fa-tint'></i>" },
   { is_recording_interface: true, icon: "<i class='fas fa-hdd'></i>" },
]

const getInterfaceIcon = (interface_types) => {
   for (const [key, value] of Object.entries(interface_types)) {
      const interface_info = interfaces.find((el) => el[key] ? (el[key] === value) : false)
      if (interface_info) {
         return interface_info.icon;
      }
   }
   return ''
}

const interfaceUtils = function () {
   return {
      getInterfaceIcon
   };
}();

export default interfaceUtils;