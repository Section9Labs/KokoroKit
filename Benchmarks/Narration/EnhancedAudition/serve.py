#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Local audition server with bounded byte-range streaming for mobile audio."""
import argparse, functools, http.server, pathlib, re

class Handler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        self.byte_range = None
        path = pathlib.Path(self.translate_path(self.path))
        if 'Range' not in self.headers or not path.is_file():
            return super().send_head()
        size = path.stat().st_size
        match = re.fullmatch(r'bytes=(\d*)-(\d*)', self.headers['Range'])
        if not match or not any(match.groups()) or size == 0:
            self.send_error(416); return None
        first,last = match.groups()
        start = int(first) if first else max(0,size-int(last))
        end = min(size-1,int(last)) if first and last else size-1
        if not 0 <= start <= end < size:
            self.send_response(416); self.send_header('Content-Range',f'bytes */{size}');self.end_headers();return None
        file = path.open('rb'); file.seek(start); self.byte_range = (start,end)
        self.send_response(206)
        self.send_header('Content-Type',self.guess_type(str(path)))
        self.send_header('Content-Length',str(end-start+1))
        self.send_header('Content-Range',f'bytes {start}-{end}/{size}')
        self.send_header('Accept-Ranges','bytes');self.end_headers();return file

    def copyfile(self,source,outputfile):
        if self.byte_range is None:
            return super().copyfile(source,outputfile)
        remaining=self.byte_range[1]-self.byte_range[0]+1
        try:
            while remaining:
                chunk=source.read(min(65536,remaining))
                if not chunk:break
                outputfile.write(chunk);remaining-=len(chunk)
        except (BrokenPipeError,ConnectionResetError):pass

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--directory',type=pathlib.Path,required=True);p.add_argument('--port',type=int,default=8876);a=p.parse_args()
    root=a.directory.resolve();assert (root/'audition.json').is_file()
    http.server.ThreadingHTTPServer(('0.0.0.0',a.port),functools.partial(Handler,directory=str(root))).serve_forever()
