#!/usr/bin/python
import sys
try:
    import argparse
except:
    print("*** Please install 'argparse' for me to work")
    sys.exit(1)
try:
    import pexpect
except:
    print("*** Please install 'pexpect' for me to work")
    sys.exit(1)
import getpass
import os

def check_key(host, id_key):
    command = '/usr/bin/ssh {0} "sort -u .ssh/authorized_keys -o .ssh/authorized_keys; grep -c \'{1}\' .ssh/authorized_keys"'.format(host, id_key)
    child = pexpect.spawn('/bin/bash', ['-c', command])
    a = child.expect( [ '[1-9]+',
        '0',
        '.*No such file or directory',
        pexpect.EOF,
        pexpect.TIMEOUT,
        '.*assword:',
        'Are you sure you want to continue connecting.*',
        '.*nodename nor servname provided.*',
        '.*forward host lookup failed.*'], timeout=4 )
    if a == 0:
        print("[:)] Your key is already present.")
        return True
    elif a == 1 or a == 2 or a == 3 or a == 5 or a == 6:
        print("[ii] You key wasn't found.")
        return False
    elif a == 7 or a == 8:
        print("[!!] Host not found.")
        return True # hackety hack
    elif a == 4:
        print("[!!] Timout occured.")
        return True


def main():
    parser = argparse.ArgumentParser(description='Easily distribute ssh keys')
    parser.add_argument('--hostlist', metavar='FILE', help='List containing hosts to ssh to, one per line')
    parser.add_argument('--key', metavar='PUBKEYFILE', help='Path to public key file', default=os.path.expanduser('~/.ssh/id_rsa.pub'))
    parser.add_argument('--host', metavar='HOST', help='Single host to put your key to')

    args = parser.parse_args()

    if not args.hostlist and not args.host:
        print("[??] Whatcha want, buddy?")
        parser.print_usage()
        sys.exit(0)

    if args.hostlist and args.host:
        print("[!!] You can't have both hostlist and host. Pick one")
        parser.print_usage()
        sys.exit(0)

    hosts = []

    if args.hostlist:
        try:
            hosts = [line.strip() for line in open(args.hostlist)]

        except IOError:
            print("[!!] File {} can't be found.".format(args.hostlist))
            sys.exit(1)

    if args.host:
        hosts.append(args.host)

    try:
        id_key = open(args.key, 'r').read().strip()
    except IOError:
        print("[!!] Public key file {} can't be found.".format(args.key))
        sys.exit(1)

    try:
        password = getpass.getpass('Type password in. We shall asssume it is the same for everything: ')
        for host in hosts:
            print("[!!] Processing {}".format(host))

            if check_key(host, id_key):
                continue

            command = 'echo {0} | /usr/bin/ssh {1} "umask 077; test -d .ssh || mkdir .ssh ; cat >> .ssh/authorized_keys"'.format(id_key, host)
            print("[ii] Placing key...")
            child = pexpect.spawn('/bin/bash', ['-c', command])
            ret = child.expect( [ 'Are you sure you want to continue connecting.*',
                '.*assword:',
                '.*nodename nor servname provided.*',
                pexpect.EOF, pexpect.TIMEOUT,
                'Password:' ], timeout=4 )
            if ret == 0:
                print("[++] Accepting hostkey")
                child.sendline("yes")
                b = child.expect([ '.*assword:', pexpect.EOF, pexpect.TIMEOUT ], timeout=10)
                if b == 0:
                    print("[--] Sending password")
                    child.sendline(password)
                    c = child.expect([ '.*assword:', pexpect.EOF, pexpect.TIMEOUT ], timeout=10)
                    if c == 0:
                        print("[!!] Login failed.")
                        continue
                    elif c == 2:
                        print("[!!] Timeout occured.")
                        continue
                    else:
                        print("[:)] Key placed.")
            elif ret == 1 or ret == 5:
                print("[--] Sending password")
                child.sendline(password)
                b = child.expect([ '.*assword:', pexpect.EOF, pexpect.TIMEOUT ], timeout=10)
                if b == 0:
                    print("[!!] Login failed.")
                    continue
                elif b == 2:
                    print("[!!] Timeout occured.")
                    continue
                else:
                    print("[:)] Key placed.")
            elif ret == 2:
                print("[!!] Host {} can't be resolved.".format(host))
            elif ret == 3:
                print("[:)] Key placed.")
            elif ret == 4:
                print("[!!] Connection timeout occured.")


    except KeyboardInterrupt:
        print("[:|] Aborted by user.")
        sys.exit(0)

if __name__ == '__main__':
    main()
