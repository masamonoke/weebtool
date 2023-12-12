
def log(logger, text)
  logger.debug(text) unless logger.nil?
end

