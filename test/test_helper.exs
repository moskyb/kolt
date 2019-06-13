Application.ensure_all_started(:mimic)
Mimic.copy(:brod)
Mimic.copy(:telemetry)
ExUnit.start()
