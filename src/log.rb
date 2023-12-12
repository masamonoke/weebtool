module Weebtool
  def log(text)
    $logger.debug(text) unless $logger.nil?
  end
end
