from http.server import BaseHTTPRequestHandler, HTTPServer
from scipy.spatial import ConvexHull

class RequestHandler(BaseHTTPRequestHandler):
	def do_GET(self):
		arr = []
		params = int(self.path.split('params=')[1].split('&')[0])
		for i in range(params):
			idx_str = str(i) + '='
			arr.append([float(self.path.split('x' + idx_str)[1].split('&')[0]),
					float(self.path.split('y' + idx_str)[1].split('&')[0]),
					float(self.path.split('z' + idx_str)[1].split('&')[0])])
		hull = ConvexHull(arr)
		
		message = ""
		for i in range(len(hull.simplices)):
			a, b, c = hull.simplices[i]
			equation_z = hull.equations[i][2]
			message += str(a) + " " + str(b) + " " + str(c) + " " + str(equation_z) + "\n"
		message = message.encode()
		
		self.send_response(200)
		self.send_header('Content-type', 'text/plain')
		self.send_header('Content-length', len(message))
		self.end_headers()
		self.wfile.write(message)
		self.wfile.flush()

server_address = ('', 8000)
httpd = HTTPServer(server_address, RequestHandler)
httpd.serve_forever()
