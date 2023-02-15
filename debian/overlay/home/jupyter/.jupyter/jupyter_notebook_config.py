c.ServerApp.allow_password_change = False
c.ServerApp.allow_root = True
c.ServerApp.base_url = '/jlab'
c.ServerApp.disable_check_xsrf = False
c.ServerApp.ip = '*'
c.ServerApp.root_dir = '/home/jupyter'
c.ServerApp.open_browser = False
c.ServerApp.password_required = False
c.ServerApp.port = 8888 # port on which you want to host the lab
c.ServerApp.allow_remote_access = True
c.ServerApp.token = u''

c.NotebookApp.nbserver_extensions = { 'jupyterlab' : True }
c.NotebookApp.tornado_settings = {'static_url_prefix': '/jlab/static/'}
