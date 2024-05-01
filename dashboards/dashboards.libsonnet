local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local timeSeriesPanel = g.panel.timeSeries;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

// Stat
local stOptions = statPanel.options;
local stStandardOptions = statPanel.standardOptions;
local stQueryOptions = statPanel.queryOptions;
local stPanelOptions = statPanel.panelOptions;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

local capitalize = function(str) std.asciiUpper(std.substr(str, 0, 1)) + std.substr(str, 1, std.length(str));

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source'),

    local summaryJobVariable =
      query.new(
        'job',
        'label_values(probe_success{}, job)'
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local detailsJobVariable =
      query.new(
        'job',
        'label_values(probe_success{}, job)'
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local instanceVariable =
      query.new(
        $._config.humanReadableLabel,
        'label_values(probe_success{job=~"$job"}, %s)' % $._config.humanReadableLabel,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel(capitalize($._config.humanReadableLabel)) +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local summaryVariables = [
      datasourceVariable,
      summaryJobVariable,
    ],
    local detailsVariables = [
      datasourceVariable,
      detailsJobVariable,
      instanceVariable,
    ],

    local statusMapQuery = |||
      sum by (job, %s) (
        probe_success{
          job=~"$job"
        }
      )
    ||| % $._config.humanReadableLabel,

    local statusMapStatPanel =
      statPanel.new(
        'Status Map',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          statusMapQuery,
        ) +
        prometheus.withLegendFormat(
          '{{%s}}' % $._config.humanReadableLabel
        ),
      ) +
      stOptions.withTextMode('value_and_name') +
      stOptions.text.withTitleSize(18) +
      stOptions.text.withValueSize(18) +
      stOptions.withColorMode('background') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('short') +
      stQueryOptions.withMaxDataPoints(100) +
      stStandardOptions.withMappings(
        stStandardOptions.mapping.ValueMap.withType('value') +
        stStandardOptions.mapping.ValueMap.withOptions(
          {
            '0': { text: 'Down', color: 'red' },
            '1': { text: 'Up', color: 'green' },
          }
        )
      ) +
      stStandardOptions.withLinks([
        stPanelOptions.link.withTitle('Go To Probe') +
        stPanelOptions.link.withType('link') +
        stPanelOptions.link.withUrl(
          'd/' + $._config.detailsDashboardUid + '/blackbox-exporter-%(humanReadableLabel)s-details?var-%(humanReadableLabel)s=${__field.labels.%(humanReadableLabel)s}&var-job=${__field.labels.job}' % $._config,
        ),
      ]),

    local probesQuery = |||
      count(
        probe_success{
          job=~"$job"
        }
      )
    |||,

    local probesStatPanel =
      statPanel.new(
        'Probes',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          probesQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.001) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local probesSuccessQuery = |||
      (
        count(
          probe_success{
            job=~"$job"
          } == 1
        )
        OR vector(0)
      ) /
      count(
        probe_success{
          job=~"$job"
        }
      )
    |||,

    local probesSuccessStatPanel =
      statPanel.new(
        'Probes Success',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          probesSuccessQuery,
        )
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('percentunit') +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.99) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(0.999) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local probesSSLQuery = |||
      count(
        probe_http_ssl{
          job=~"$job"
        } == 1
      ) /
      count(
        probe_http_version{
          job=~"$job"
        }
      )
    |||,

    local probesSSLStatPanel =
      statPanel.new(
        'Probes SSL',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          probesSSLQuery,
        )
      ) +
      stStandardOptions.withUnit('percentunit') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.999) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local probeDurationQuery = |||
      avg(
        probe_duration_seconds{
          job=~"$job"
        }
      )
    |||,

    local probeDurationStatPanel =
      statPanel.new(
        'Probe Average Duration',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          probeDurationQuery,
        )
      ) +
      stStandardOptions.withUnit('s') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']),

    local uptimeQuery = |||
      sum by (job, %(humanReadableLabel)s) (
        probe_success{
          job=~"$job",
          %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
        }
      )
    ||| % $._config,

    local uptimeStatPanel =
      statPanel.new(
        'Uptime',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          uptimeQuery,
        )
      ) +
      stStandardOptions.withUnit('percentunit') +
      stOptions.withColorMode('background') +
      stOptions.reduceOptions.withCalcs(['mean']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.99) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(0.999) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local probeSuccessQuery = |||
      probe_success{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local probeSuccessStatPanel =
      statPanel.new(
        'Probe Success',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          probeSuccessQuery,
        ) +
        prometheus.withInstant(true),
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.withColorMode('background') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withMappings(
        stStandardOptions.mapping.ValueMap.withType('value') +
        stStandardOptions.mapping.ValueMap.withOptions(
          {
            '0': { text: 'No', color: 'red' },
            '1': { text: 'Yes', color: 'green' },
          }
        )
      ),

    local latestResponseCodeQuery = |||
      probe_http_status_code{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local latestResponseCodeStatPanel =
      statPanel.new(
        'Latest Response Code',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          latestResponseCodeQuery,
        ) +
        prometheus.withInstant(true),
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('short') +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(300) +
        stStandardOptions.threshold.step.withColor('blue'),
        stStandardOptions.threshold.step.withValue(400) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(500) +
        stStandardOptions.threshold.step.withColor('red'),
      ]),

    local sslQuery = |||
      probe_http_ssl{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local sslStatPanel =
      statPanel.new(
        'SSL',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          sslQuery,
        ) +
        prometheus.withInstant(true),
      ) +
      stOptions.withColorMode('background') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('short') +
      stStandardOptions.withMappings([
        stStandardOptions.mapping.ValueMap.withType('value') +
        stStandardOptions.mapping.ValueMap.withOptions(
          {
            '0': { text: 'No', color: 'red' },
            '1': { text: 'Yes', color: 'green' },
          }
        ),
      ]),

    local sslVersionQuery = |||
      probe_tls_version_info{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local sslVersionStatPanel =
      statPanel.new(
        'SSL Version',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          sslVersionQuery,
        ) +
        prometheus.withInstant(true) +
        prometheus.withLegendFormat('{{version}}')
      ) +
      stOptions.withTextMode('name') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('short') +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local redirectsQuery = |||
      probe_http_redirects{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local redirectsStatPanel =
      statPanel.new(
        'Redirects',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          redirectsQuery,
        ) +
        prometheus.withInstant(true),
      ) +
      stOptions.withColorMode('background') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withUnit('short') +
      stStandardOptions.withMappings(
        stStandardOptions.mapping.ValueMap.withType('value') +
        stStandardOptions.mapping.ValueMap.withOptions(
          {
            '0': { text: 'No', color: 'green' },
            '1': { text: 'Yes', color: 'blue' },
          }
        ),
      ),

    local httpVersionQuery = |||
      probe_http_version{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local httpVersionStatPanel =
      statPanel.new(
        'HTTP Version',
      ) +
      stStandardOptions.withUnit('short') +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          httpVersionQuery,
        ) +
        prometheus.withInstant(true) +
        prometheus.withLegendFormat('{{version}}'),
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']),


    local sslCertificateExpiryQuery = |||
      probe_ssl_earliest_cert_expiry{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      } - time()
    ||| % $._config,

    local sslCertificateExpiryStatPanel =
      statPanel.new(
        'SSL Certificate Expiry',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          sslCertificateExpiryQuery,
        )
      ) +
      stOptions.withColorMode('background') +
      stOptions.withGraphMode('none') +
      stStandardOptions.withUnit('s') +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(1814400) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local averageLatencyQuery = |||
      probe_duration_seconds{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local averageLatencyStatPanel =
      statPanel.new(
        'Average Latency',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          averageLatencyQuery,
        )
      ) +
      stStandardOptions.withUnit('s') +
      stOptions.reduceOptions.withCalcs(['mean']),

    local averageDnsLookupQuery = |||
      probe_dns_lookup_time_seconds{
        job=~"$job",
        %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
      }
    ||| % $._config,

    local averageDnsLookupStatPanel =
      statPanel.new(
        'Average DNS Lookup Latency',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          averageDnsLookupQuery,
        )
      ) +
      stStandardOptions.withUnit('s') +
      stOptions.reduceOptions.withCalcs(['mean']),

    local probeHttpDurationQuery = |||
      sum(
        probe_http_duration_seconds{
          job=~"$job",
          %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
        }
      ) by (%(humanReadableLabel)s)
    ||| % $._config,
    local probeTotalDurationQuery = std.strReplace(probeHttpDurationQuery, 'probe_http_duration_seconds', 'probe_duration_seconds'),

    local probeDurationTimeSeriesPanel =
      timeSeriesPanel.new(
        'Probe Duration',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            probeHttpDurationQuery,
          ) +
          prometheus.withLegendFormat(
            'HTTP duration'
          ),
          prometheus.new(
            '$datasource',
            probeTotalDurationQuery,
          ) +
          prometheus.withLegendFormat(
            'Total probe duration'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10) +
      tsCustom.withSpanNulls(false),


    local probeHttpPhaseDurationQuery = |||
      sum(
        probe_http_duration_seconds{
          job=~"$job",
          %(humanReadableLabel)s=~"$%(humanReadableLabel)s"
        }
      ) by (phase)
    ||| % $._config,
    local probeIcmpPhaseDurationQuery = std.strReplace(probeHttpPhaseDurationQuery, 'probe_http_duration_seconds', 'probe_icmp_duration_seconds'),

    local probePhaseTimeSeriesPanel =
      timeSeriesPanel.new(
        'Probe Phases',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            probeHttpPhaseDurationQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ phase }}'
          ),
          prometheus.new(
            '$datasource',
            probeIcmpPhaseDurationQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ phase }}'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('percent') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local summaryRow =
      row.new(
        title='Summary'
      ),

    local individualProbesRow =
      row.new(
        title='$target',
      ) +
      row.withRepeat('target'),

    'blackbox-exporter-summary.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Blackbox Exporter / Summary',
      ) +
      dashboard.withDescription('A dashboard that monitors the Blackbox-exporter. It is created using the blackbox-exporter-mixin for the the (blackbox-exporter)[https://github.com/prometheus/blackbox-exporter].') +
      dashboard.withUid('blackbox-exporter-summary-kc8nbr') +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-2d') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(summaryVariables) +
      dashboard.withPanels(
        [
          summaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          statusMapStatPanel +
          statPanel.gridPos.withX(0) +
          statPanel.gridPos.withY(1) +
          statPanel.gridPos.withW(24) +
          statPanel.gridPos.withH(5),
        ] +
        grid.makeGrid(
          [probesStatPanel, probesSuccessStatPanel, probesSSLStatPanel, probeDurationStatPanel],
          panelWidth=6,
          panelHeight=4,
          startY=6
        )
      ),

    'blackbox-exporter-details.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Blackbox Exporter / ' + capitalize($._config.humanReadableLabel) + ' Details',
      ) +
      dashboard.withDescription('A dashboard that monitors the Blackbox-exporter. It is created using the blackbox-exporter-mixin for the the (blackbox-exporter)[https://github.com/prometheus/blackbox-exporter].') +
      dashboard.withUid('blackbox-exporter-details-mz7l7e') +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-2d') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(detailsVariables) +
      dashboard.withLinks([
        dashboard.link.link.new('Summary all', 'd/' + $._config.summaryDashboardUid + '/blackbox-exporter-summary'),
        dashboard.link.link.new('Summary this Job', 'd/' + $._config.summaryDashboardUid + '/blackbox-exporter-summary?var-job=$job'),
      ]) +
      dashboard.withPanels(
        [
          individualProbesRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(10) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          uptimeStatPanel +
          statPanel.gridPos.withX(0) +
          statPanel.gridPos.withY(11) +
          statPanel.gridPos.withW(6) +
          statPanel.gridPos.withH(4),
        ] +
        grid.makeGrid(
          [probeSuccessStatPanel, latestResponseCodeStatPanel],
          panelWidth=3,
          panelHeight=3,
          startY=15
        ) +
        grid.makeGrid(
          [sslStatPanel, sslVersionStatPanel],
          panelWidth=3,
          panelHeight=3,
          startY=18
        ) +
        [
          sslCertificateExpiryStatPanel +
          statPanel.gridPos.withX(0) +
          statPanel.gridPos.withY(21) +
          statPanel.gridPos.withW(6) +
          statPanel.gridPos.withH(3),
        ] +
        grid.makeGrid(
          [redirectsStatPanel, httpVersionStatPanel],
          panelWidth=3,
          panelHeight=3,
          startY=24
        ) +
        grid.makeGrid(
          [averageLatencyStatPanel, averageDnsLookupStatPanel],
          panelWidth=3,
          panelHeight=4,
          startY=27
        ) +
        [
          probeDurationTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(6) +
          timeSeriesPanel.gridPos.withY(11) +
          timeSeriesPanel.gridPos.withW(18) +
          timeSeriesPanel.gridPos.withH(10),
          probePhaseTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(6) +
          timeSeriesPanel.gridPos.withY(21) +
          timeSeriesPanel.gridPos.withW(18) +
          timeSeriesPanel.gridPos.withH(10),
        ]
      ),
  },
}
