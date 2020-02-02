require 'rack'

Rack::Mime::MIME_TYPES.merge!({
  ".wasm"     => "application/wasm",
})

builder = Rack::Builder.new do
  map "/" do
    use Rack::Static, urls: [""],
                      root: File.expand_path('./'),
                      index: 'index.html'
    run lambda {}
  end
end

Rack::Handler::WEBrick.run builder
