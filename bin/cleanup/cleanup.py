#!/usr/bin/env python3
import psycopg2
import psycopg2.extras
from kubernetes import client as kubectl, config as kube_config
import re

DECRYPTER_NAME_RE = re.compile(r"^decrypter-([0-9A-F]{8}-[0-9A-F]{4}-[4][0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12})$",
                               flags=re.IGNORECASE)


def connect():
    """
    Connect to the sos database.

    Uses ~/.pgpass for credentials.
    :return:  connection
    """
    conn = psycopg2.connect(
        dbname="streams",
        user="streams_user",
        host="localhost",
        port=55433,
        options=f"--search_path=sos"
    )
    return conn


def get_all_streams():
    cur = connect().cursor(cursor_factory=psycopg2.extras.DictCursor)
    cur.execute("select * from streams")
    return cur.fetchall()

def get_all_decrypters():
    cur = connect().cursor(cursor_factory=psycopg2.extras.DictCursor)
    cur.execute("""select distinct concat('decrypter-', dl.decrypter_id) i 
    from sos.decrypter_links dl 
    join sos.streams t 
    on dl.stream_name = t."name" and dl.billing_id = t.billing_id order by i;
    """)
    return cur.fetchall()

def get_configmaps():
    kube_config.load_kube_config()
    v1 = kubectl.CoreV1Api()
    return v1.list_namespaced_config_map("customers", watch=False)


def is_decrypter_cm(metadata):
    try:
        return metadata.labels["app"] == "decrypter-v1" and DECRYPTER_NAME_RE.match(metadata.name)
    except Exception as e:
        pass




sos = get_all_streams()
config_maps = get_configmaps()

decrypter_maps = [c for c in config_maps.items if is_decrypter_cm(c.metadata)]

# for m in decrypter_maps: print(m.metadata.labels)


sos_decrypters = [s['id'] for s in sos if s['linked_stream_name']]


print("done")