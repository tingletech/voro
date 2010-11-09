#! /usr/bin/env python

"""
Update the voroEAD system with current data from the OAC Django DB.

This is designed to be a single utility that is run for updating users and
institutions in the voroEAD system. It uses the dump_django.pl script to
generate the repodata structure and the voro.users.txt & voro.groups.txt and 
the users.digest file for digest authentication.
build.users.pl generates the apache conf & groups for webdav access.
It also checks that the various directory structures are in place-maybe this is best put into dump_django?

"""
import os, sys
import os.path
import logging, logging.handlers
from config_reader import read_config

HOME = os.environ['HOME']


#setup some globals for file locations and names
DIR_EXE = HOME + '/branches/production/voro/batch-bin/'
DIR_DATA = HOME + '/data/in/oac-ead/'
DIR_IN = HOME + '/users/in/'
DIR_APACHE_WEBDAV_CONF = HOME + '/users/apache/'
DIR_EAD_TEST = HOME + '/workspace/test-oac/submission'
#subdirs for data, from DIR_DATA root path
DIR_SUB_REPO = 'repodata'
DIR_SUB_SUBMISSION = DIR_DATA + 'submission'
#DIR_SUB_EAD_PRODUCTION = 'prime2002'
DIR_LOGGING = HOME + '/log/update_voroEAD/'

db = read_config()

DATABASE_HOST = db['default-ro']['HOST']
DATABASE_NAME = db['default-ro']['NAME']
DATABASE_USER = db['default-ro']['USER']
DATABASE_PASSWORD = db['default-ro']['PASSWORD']
DATABASE_PORT = db['default-ro']['PORT']

FILE_VOROUSERS = 'voro.users.txt' # HARDCODED in build.users.pl
FILE_VOROGROUPS = 'voro.groups.txt' # HARDCODED in build.users.pl
FILE_APACHE_DIGEST = 'users.digest'
FILE_APACHE_GROUPS = 'groups' # HARDCODED in build.users.pl
FILE_APACHE_DAV_CONF = 'DAV.conf'  # HARDCODED in build.users.pl
FILE_LOGGING = 'voro_update.log'

LOG_LEVEL = logging.INFO

# TODO: wrap apachectl with vcs freeze cmd
APACHECTL = HOME + '/servers/back/bin/apachectl'

def setup_logger():
    log = logging.getLogger()
    log.setLevel(LOG_LEVEL)
    # this only seems to work in long running procs h = logging.handlers.TimedRotatingFileHandler(os.path.join(DIR_LOGGING, FILE_LOGGING), when='H', interval=1, backupCount=24 )
    h = logging.handlers.RotatingFileHandler(os.path.join(DIR_LOGGING, FILE_LOGGING), maxBytes=1000000, backupCount=24 )
    h.setLevel(LOG_LEVEL)
    format = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    h.setFormatter(format)
    log.addHandler(h)
    return log

def main():
    setup_logger()
    logging.info("!!!!START OF update_voroEAD.py PROCESS!!!!")
    # call dump_django.pl
    
    prog = os.path.join(DIR_EXE, 'dump_django.pl')
    repodir = os.path.join(DIR_DATA, DIR_SUB_REPO)
    userfile = os.path.join(DIR_IN, FILE_VOROUSERS)
    groupfile = os.path.join(DIR_IN, FILE_VOROGROUPS) 
    htdigestfile = os.path.join(DIR_APACHE_WEBDAV_CONF, FILE_APACHE_DIGEST)
    
    dump_django_cmd = ' '.join([prog, repodir, userfile, groupfile, htdigestfile,
                                DATABASE_HOST, DATABASE_PORT, DATABASE_NAME,
                                DATABASE_USER, DATABASE_PASSWORD, 
                               ]
                              )
    logging.info('dump_django_cmd ='+dump_django_cmd)
    err = os.system(dump_django_cmd)
    if err:
        logging.error( "ERROR DURING dump_django")
        sys.exit(1)
    
    logging.info( "dump_django.pl succeeded. build.users.pl next")
    
    prog = os.path.join(DIR_EXE, 'build.users.pl')
    build_users_cmd = ' '.join(['perl', prog])
    err = os.system(build_users_cmd)
    if err:
        logging.error( "ERROR DURING build.users")
        sys.exit(1)
    
    logging.info( "build.users.pl succeeded. Check directory trees next")
    
    # This is a bit hokey below. Should access the Django db directly, but 
    # then we must install the MySQL python lib. Would also be nice to parse the
    # DAV.conf xml with ElementTree, but that is only included in python 2.5+
    # so I just do some string matching
    
    # first get all lines that have <Directory /voro/data/oac-ead in them
    davfilename = os.path.join(DIR_APACHE_WEBDAV_CONF, FILE_APACHE_DAV_CONF)
    davfile = file(davfilename)
    lines = davfile.readlines()
    davfile.close()
    dirlines = [l.strip() for l in lines if l.find("<Directory /voro/data/oac-ead") == 0]
    #Change made to add marc & ead-pdf on 20100427 necessitated change below
    #now use the full directory listing in the DAV.conf to create directories
    #NOTE: The one wrinkle is that the production dir is not a DAV dir,
    #though we know that it corresponds to the submission dir
    dirs = [l[l.find('/'):-1] for l in dirlines]
    #logging.info(dirs)
    
    # now create directory if it doesn't exist
    created = False
    for d in dirs:
        if not os.path.isdir(d):
            logging.info("Creating directory:%s" % d)
            print "Creating directory:%s" % d
            os.makedirs(d)
            created = True
        if d.find(DIR_SUB_SUBMISSION) != -1:
            proddir = d.replace('submission', 'prime2002')
            if not os.path.isdir(proddir):
            	logging.info( "Creating dir:%s" % proddir)
            	print "Creating dir:%s" % proddir
            	os.makedirs(proddir)
                created = True
            testdir = d.replace('data/oac-ead', 'workspace/test-oac')
            if not os.path.isdir(testdir):
            	logging.info( "Creating dir:%s" % testdir)
            	print "Creating dir:%s" % testdir
            	os.makedirs(testdir)
                created = True

    msg = "Directoris created during update, see above. " if created else ""
    msg += "Attempt apache restart next."
    logging.info(msg)
    
    apache_cmd = ' '.join([APACHECTL, 'restart'])
    logging.info('apache_cmd:'+apache_cmd)
    err = os.system(apache_cmd)
    logging.info("!!!!END OF update_voroEAD.py PROCESS!!!!")
    
if __name__=="__main__":
    main()
