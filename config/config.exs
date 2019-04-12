use Mix.Config

config :logger, backends: []

if Mix.env() == :test do
  if System.get_env("CI") do
    config :faktory_worker, :tls_server,
      host: "faktory_tls",
      port: 7419

    config :faktory_worker, :passworded_server,
      host: "faktory_password",
      port: 7419
  else
    config :faktory_worker, :tls_server,
      host: "localhost",
      port: 7519

    config :faktory_worker, :passworded_server,
      host: "localhost",
      port: 7619
  end
end

# import_config "#{Mix.env()}.exs"
