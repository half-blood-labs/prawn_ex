# PrawnEx configuration.
# When using PrawnEx as a dependency, set :image_dir in your app's config so
# relative paths in PrawnEx.image/3 are resolved from that directory.
#
# Example (in your application's config/config.exs):
#   config :prawn_ex, image_dir: "priv/images"
#
# For the demo script in this project, we default to "assets".
import Config

config :prawn_ex, image_dir: "assets"
