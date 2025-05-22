/*
  (C) 2013-24 - ntop.org
 */

const active_monitoring_type = [
   { name: i18n('active_monitoring_stats.icmp_continuous'), id: 'cicmp' },
   { name: i18n('active_monitoring_stats.speedtest'), id: 'speedtest' },
   { name: i18n('active_monitoring_stats.throughput'), id: 'throughput' },
   { name: i18n('active_monitoring_stats.icmp_continuous_v6'), id: 'cicmp6' },
   { name: i18n('active_monitoring_stats.icmp'), id: 'icmp' },
   { name: i18n('active_monitoring_page.http'), id: 'http' },
]

const getActiveMonitoringName = (id) => {
   const obj = active_monitoring_type.find(el => el.id === id);
   if (obj) {
      return obj.name;
   }
   return id;
}

const activeMonitoringUtils = function () {
   return {
      getActiveMonitoringName
   };
}();

export default activeMonitoringUtils;