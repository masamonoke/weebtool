
module Weebtool

  class Config
    def self._init()
      if @config.nil?
        @config = YAML.load_file("config.yml")
      end
    end

    def self.config()
      _init()
      return @config
    end
  end

end
