#!/usr/bin/env python

"""
    Focus HTTP Blackhole proxy
"""
import optparse, socket, thread

class ProxyConnectionHandler(object):
    def __init__(self, connection, address, timeout=60, content="Get back to work!", **kwargs):
        
        headers = [
            "HTTP/1.1 200 OK",
            "Content-type: text/html",
            "Cache-Control: no-cache, max-age=0, must-revalidate, no-store",
            "Content-length: %d" % len(content),
        ]
            
        headerstr = "\r\n".join(headers)
        body = "%s\r\n\r\n%s" % (headerstr, content)
                   
        connection.send(body)
        connection.close()

def start_proxy(host='localhost', port=8401, content="Get back to work!"):

    try:
        print "Serving blackhole proxy on %s:%d" % (host, port)
        soc = socket.socket(socket.AF_INET)
        soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        soc.bind((host, port))
        soc.listen(0)

        kwargs = {"content": content}

        while True:
            args = soc.accept() + (1,)
            thread.start_new_thread(ProxyConnectionHandler, args, kwargs)
    except:
        print "Shutting blackhole proxy down..."
        soc.close()
        raise
        

if __name__ == '__main__':

    parser = optparse.OptionParser()
    parser.add_option("-t", "--template")
    (opts, args) = parser.parse_args()

    kwargs = {}

    if opts.template:
        try: kwargs["content"] = open(opts.template).read()
        except: pass

    start_proxy(**kwargs)
