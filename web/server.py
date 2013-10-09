#!/usr/bin/python
import web

class ServerApplication(web.application):
    def run(self, port=80, *middleware):
        func = self.wsgifunc(*middleware) 
        return web.httpserver.runsimple(func, ('0.0.0.0', port)) 

urls = (
    '/', 'index'
)

class index:
    def GET(self):
        return "Hello from Copper.io!"

if __name__ == "__main__":
    app = ServerApplication(urls, globals())
    app.run(port = 80)
