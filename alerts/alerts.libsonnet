{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'blackbox-exporter.rules',
        rules: [
          {
            alert: 'BlackboxProbeFailed',
            expr: |||
              probe_success == 0
            |||,
            'for': $._config.probeFailedInterval,
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Probe has failed for the past %(probeFailedInterval)s interval.' % $._config,
              description: 'The probe failed for the instance {{ $labels.%(humanReadableLabel)s }}.' % $._config,
              dashboard_url: '%(grafanaUrl)s/d/%(detailsDashboardUid)s/blackbox-exporter-details?job={{ $labels.job }}&%(humanReadableLabel)s={{ $labels.%(humanReadableLabel)s }}' % $._config,
            },
          },
          {
            alert: 'BlackboxLowUptime%(uptimePeriodDays)sd' % $._config,
            expr: |||
              avg_over_time(probe_success[%(uptimePeriodDays)sd]) * 100 < %(uptimeThreshold)s
            ||| % $._config,
            labels: {
              severity: 'info',
            },
            annotations: {
              summary: 'Probe uptime is lower than %(uptimeThreshold)g%% for the last %(uptimePeriodDays)s days.' % $._config,
              description: 'The probe has a lower uptime than %(uptimeThreshold)g%% the last %(uptimePeriodDays)s days for the instance {{ $labels.instance }}.' % $._config,
              dashboard_url: '%(grafanaUrl)s/d/%(detailsDashboardUid)s/blackbox-exporter-details?job={{ $labels.job }}&%(humanReadableLabel)s={{ $labels.%(humanReadableLabel)s }}' % $._config,
            },
          },
          {
            alert: 'BlackboxSslCertificateWillExpireSoon',
            expr: |||
              probe_ssl_earliest_cert_expiry - time() < %(probeSslExpireDaysThreshold)s * 24 * 3600
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'SSL certificate will expire soon.',
              description: |||
                The SSL certificate of the instance {{ $labels.instance }} is expiring within %(probeSslExpireDaysThreshold)s days.
                Actual time left: {{ $value | humanizeDuration }}.
              ||| % $._config,
              dashboard_url: '%(grafanaUrl)s/d/%(detailsDashboardUid)s/blackbox-exporter-details?job={{ $labels.job }}&%(humanReadableLabel)s={{ $labels.%(humanReadableLabel)s }}' % $._config,
            },
          },
        ],
      },
    ],
  },
}
