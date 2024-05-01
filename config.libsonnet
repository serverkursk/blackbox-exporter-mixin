{
  _config+:: {
    // Bypasses grafana.com/dashboards validator
    bypassDashboardValidation: {
      __inputs: [],
      __requires: [],
    },

    grafanaUrl: 'https://grafana.com',
    summaryDashboardUid: 'blackbox-exporter-summary-kc8nbr',
    detailsDashboardUid: 'blackbox-exporter-details-mz7l7e',
    tags: ['blackbox-exporter', 'blackbox-exporter-mixin'],

    // The period in days to consider for the uptime evaluation
    uptimePeriodDays: 30,
    // Will alert if below the percentage for the configured uptime period
    uptimeThreshold: 99.9,
    // The period in minutes to consider for the probe to fail
    probeFailedInterval: '1m',

    //Cert-manager defaults to 3 week renewal time
    probeSslExpireDaysThreshold: '21',

    humanReadableLabel: 'instance',
  },
}
