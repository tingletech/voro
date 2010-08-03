''' Provides the ois (Object Info Service) cgi interface
    Input: ark of dao, finding aid ark (ark_parent)
    Returns: order of dao in parent
    name of parent institution
    name of grandparent institution
'''

import sqlite3 as sqlite
#import pysqlite2._sqlite as sqlite
import MySQLdb
import cgi
import re
from xml.sax.saxutils import escape

DB_SQLITE = '/voro/code/oac4/ois/ois.sqlite3'
#DB_SQLITE = '/voro/local/wsgi/ois.sqlite3'

DB_MYSQL_NAME = ''
DB_MYSQL_USER = ''
DB_MYSQL_PASSWORD = ''
DB_MYSQL_HOST = ''
DB_MYSQL_PORT = ''


def lookup_inst_names(ark_parent, ark_grandparent=None):
    '''For given ark, lookup the name in the Django DB
    '''
    conn = MySQLdb.connect(host=DB_MYSQL_HOST, user=DB_MYSQL_USER,
                           passwd=DB_MYSQL_PASSWORD, db=DB_MYSQL_NAME,
                           port=int(DB_MYSQL_PORT)
                          )
    c = conn.cursor()
    c.execute("""SELECT name from oac_institution where ark=%s""", (ark_parent,))
    name_parent = c.fetchone()
    if ark_grandparent:
        c.execute("""SELECT name from oac_institution where ark=%s""",
                  (ark_grandparent,))
        name_grandparent = c.fetchone()
    else:
        name_grandparent = (None,)

    conn.close()
    return name_parent[0], name_grandparent[0]

def lookup_info(ark, ark_parent):
    num_order = [-1,]
    if ark_parent:
       ark_object = ark
       ark_item = ark_parent
    else:
       ark_item = ark

    import sys
    sys.stderr.write("DB:%s" % DB_SQLITE)
    
    conn = sqlite.connect(DB_SQLITE)
    c = conn.cursor()
    if ark_parent:
        #lookup digital object order
        c.execute('''SELECT num_order from digitalobject where ark=? and
                  ark_findingaid=?''', (ark_object, ark_item)
                 )
        num_order = c.fetchone()
        if num_order is None:
           num_order = [-1,]
    c.execute('''SELECT ark_parent, ark_grandparent from item where
              ark=?''', (ark_item, )
             )
    arks = c.fetchone()
    if not arks:
        raise KeyError

    ark_parent, ark_grandparent = arks
    name_parent, name_grandparent = lookup_inst_names(ark_parent,
                                                      ark_grandparent)
    conn.close()
    return num_order[0], name_parent, ark_parent, name_grandparent, ark_grandparent

# WSGI interface here.
def application(environ, start_response):
    status = '200 OK'
    output = 'Hello World!'

    form = cgi.parse_qs(environ['QUERY_STRING'])
    if not form.has_key("ark"): # and form.has_key("parent_ark")):
        status = '400 NO ARKS'
        output = '<h1>NO ARK PARAMETERS</h1>'
    else:
        #verify ark format, if not formatted correctly bug out
        ark = form["ark"][0]
        try:
            ark_parent = form["parent_ark"][0]
        except KeyError:
            ark_parent = None
        ark_valid = re.compile('ark:/\d+/\w+')
        if ark_valid.search(ark) is None and ark_valid.search(ark_parent) is None:
            status = '400 INCORRECT ARK FORMAT'
            output = "<H1>ERROR: INCORRECT ARK FORMAT</H1>"
        else:
            try:
                order, name_parent, ark_parent, name_grandparent, ark_grandparent = lookup_info(ark, ark_parent)
                if not name_grandparent:
                    name_grandparent = ''
                output = ''.join(["<daoinfo>",
                             "<order>", str(order), "</order>",
                             '<inst poi="', str(ark_parent), '">', escape(name_parent), "</inst>",
			     '<inst_parent poi="', str(ark_grandparent), '">', escape(name_grandparent), "</inst_parent>",
                             "</daoinfo>"
                             ]
                            )
            except KeyError:
                status = '400 ARK NOT FOUND'
                output = "<H1>ERROR: ARK NOT FOUND</H1>"

    response_headers = [('Content-type', 'text/plain'),
                                    ('Content-Length', str(len(output)))]
    start_response(status, response_headers)
    return [output]
