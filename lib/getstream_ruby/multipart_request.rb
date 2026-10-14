# frozen_string_literal: true

module GetStream

  # Marker the generator includes in the request model of every
  # multipart/form-data operation (chat CHA-5084). The transport still picks
  # multipart from its own list in Client#multipart_request?; this module only
  # has to exist for the generated models to load.
  module MultipartRequest; end

end
