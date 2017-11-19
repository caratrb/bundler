require File.expand_path("../endpoint", __FILE__)

Artifice.deactivate

class EndpointHostRedirect < Endpoint
  get "/fetch/actual/gem/:id", :host_name => 'localgemserver.test' do
    redirect "http://carat.localgemserver.test#{request.path_info}"
  end

  get "/api/v1/dependencies" do
    status 404
  end
end

Artifice.activate_with(EndpointHostRedirect)
