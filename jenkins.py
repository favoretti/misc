#!/usr/bin/env python
import sys
import urllib2

def printHelp():
  print "deljob <hudsonurl> <jobname>"
  print "getjob <hudsonurl> <jobname>"
  print "disablejob <hudsonurl> <jobname>"
  print "enablejob <hudsonurl> <jobname>"
  print "copyh2hjob <hudson1url> <hudson2url> <jobname> [jobnewname]"
  print "listjobs <hudsonurl> [mask]"
  print "listview <hudsonurl> <view>"

def hudsonPost(url, data, contenttype="text"):
  response = ""
  try:
    req = urllib2.Request(url, data, { 'Content-Type': contenttype } )
    response = urllib2.urlopen(req)
  except urllib2.HTTPError, e:
    print "Got reponse code: %s from the server" % e.code

  return response

def hudsonGet(url):
  response = ""
  try:
    response = urllib2.urlopen(url)
  except urllib2.HTTPError, e:
    print "Got response code: %s from the server" % e.code

  return response

def normalizeUrl(url):
  if not "http://" in url:
    url = "http://" + url + "/"


  return url

def delJob(hudson, jobname):
  url = ""

  url = normalizeUrl(hudson)
  
  url += "/job/" + jobname + "/doDelete"
  print url
  hudsonPost(url, "deleteme")

if len(sys.argv) == 1:
  printHelp()
  sys.exit()

def disableJob(hudson, jobname):
  url = ""

  url = normalizeUrl(hudson)
  
  url += "/job/" + jobname + "/disable"
  print url
  hudsonPost(url, "disable")

def enableJob(hudson, jobname):
  url = ""

  url = normalizeUrl(hudson)
  
  url += "/job/" + jobname + "/enable"
  print url
  hudsonPost(url, "enable")

if len(sys.argv) == 1:
  printhelp()
  sys.exit()

def copyJobHudsonToHudson(hudson1, hudson2, jobname, newjobname):
  url = ""

  url1 = normalizeUrl(hudson1)
  url2 = normalizeUrl(hudson2)

  config = hudsonGet(url1 + "/job/" + jobname + "/config.xml").read()
  if len(config):
    print "Got config for %s from %s" % (jobname, hudson1)

  if newjobname:  
    hudsonPost(url2 + "/createItem?name=" + newjobname, config, "text/xml")
  else:
    hudsonPost(url2 + "/createItem?name=" + jobname, config, "text/xml")

def getJob(hudson, jobname):
  url = ""

  url1 = normalizeUrl(hudson)

  config = hudsonGet(url1 + "/job/" + jobname + "/config.xml").read()
  if len(config):
    print "Got config for %s from %s" % (jobname, hudson)

  print config

def listJobs(hudson, mask):
  url = ""

  url = normalizeUrl(hudson)
  url += "api/python?tree=jobs[name]"
  
  response = hudsonGet(url)

  dict = eval(response.read())

  for job in dict['jobs']:
    if mask != "" and mask in job['name']:
                   print job['name']

    if mask == "":
      print job['name']


def listView(hudson, view):
  url = ""

  url = normalizeUrl(hudson)
  url += "api/python?tree=views[name,jobs[name]]"
  
  response = hudsonGet(url)

  dict = eval(response.read())

  for nview in dict['views']:
    if view != "" and view in nview['name']:
      print "Got needed view: %s" % nview['name']
      jobs = nview['jobs']
      for job in jobs:
        print job['name']

command = sys.argv[1]
if command == "deljob":
  if len(sys.argv) < 4:
    print "deljob <hudsonurl> <jobname>"
    sys.exit()
  else:
    hudson = sys.argv[2]
    jobname = sys.argv[3]
    delJob(hudson, jobname)

elif command == "copyh2hjob":
  if len(sys.argv) < 5:
    print "copyh2hjob <hudson1url> <hudson2url> <jobname> [jobnewname]"
    sys.exit()
  else:
    hudson1 = sys.argv[2]
    hudson2 = sys.argv[3]
    jobname = sys.argv[4]
    newjobname = False

    if len(sys.argv) == 6:
      newjobname = sys.argv[5]

    copyJobHudsonToHudson(hudson1, hudson2, jobname, newjobname)  

elif command == "listjobs":
  mask = ""
  if len(sys.argv) < 3:
    print "listjobs <hudson>"
    sys.exit()

  hudson = sys.argv[2]
  if len(sys.argv) == 4:
    mask = sys.argv[3]
  listJobs(hudson, mask)  

elif command == "listview":
  view = ""
  if len(sys.argv) < 4:
    print "listview <hudson> <view>"
    sys.exit()

  hudson = sys.argv[2]
  view = sys.argv[3]
  listView(hudson, view)  

elif command == "disablejob":
  if len(sys.argv) < 4:
    print "disablejob <hudson> <job>"
    sys.exit()

  hudson = sys.argv[2]
  job = sys.argv[3]

  disableJob(hudson, job)

elif command == "enablejob":
  if len(sys.argv) < 4:
    print "enablejob <hudson> <job>"
    sys.exit()

  hudson = sys.argv[2]
  job = sys.argv[3]

  enableJob(hudson, job)

elif command == "getjob":
  if len(sys.argv) < 4:
    print "enablejob <hudson> <job>"
    sys.exit()

  hudson = sys.argv[2]
  job = sys.argv[3]

  getJob(hudson, job)
