"""Offline-only ordered wait validation; selection is always the first wait."""
from datetime import datetime, timezone
SOURCE='d37ad1f6d3c0148205c1b4d21444d05d01e7cca6'
TREE='7a49df0c816e4aa059ead494b925976cf3402498'
HASHES={'consumer_analysis/bind_consumer.py':'e157c56384458eb53e9b228751c8200acaca78cb531f1159ee61a588e4bb8006','query_analysis/bind_query.py':'6db73293a18d1d7ba1d0ac03fd8ded3ecba15d5d0aeaab5542e5ec1cb9dd3cd8'}
CAPTION='TEST Seven-day ending.'
def require(condition,message):
    if not condition: raise ValueError(message)
def utc_us(value):
    t=datetime.fromisoformat(value.replace('Z','+00:00'))
    require(t.tzinfo is not None,'Unzoned timestamp')
    d=t.astimezone(timezone.utc)-datetime(1970,1,1,tzinfo=timezone.utc)
    return (d.days*86400+d.seconds)*1000000+d.microseconds

def source_exception(origin,filename,sha):
    return origin.get('tool_source')==SOURCE and origin.get('tool_tree')==TREE and HASHES.get(filename)==sha

def validate_waits(events,pid,process_start):
    waits=[]; active=None; last=process_start; expected_hwnd=None
    for index,e in enumerate(events):
        stamp=utc_us(e['utc'])
        require(stamp>=last,'Event timestamp order invalid');last=stamp
        data=e.get('data',{});kind=e['kind']
        if kind=='native-caption-wait-start' and data.get('name')==CAPTION:
            require(active is None,'Nested ending wait')
            require(type(data['deadline_seconds']) is int and data['deadline_seconds']==30,'Ending wait deadline changed')
            require(stamp>process_start,'Wait before process start')
            active=dict(start=e,start_event_index=index,wait_ordinal=len(waits),windows=set())
        elif kind=='native-caption-wait-end' and data.get('name')==CAPTION:
            require(active is not None,'Unpaired ending wait end')
            require(stamp>utc_us(active['start']['utc']),'Wait duration invalid')
            require(len(active['windows'])==1,'Wait HWND missing or ambiguous')
            hwnd=next(iter(active.pop('windows')))
            require(expected_hwnd is None or hwnd==expected_hwnd,'Wait HWND identity changed');expected_hwnd=hwnd
            active.update(end=e,end_event_index=index,hwnd=hwnd,note='Logged interval only; not strict Stopwatch deadline admission.')
            waits.append(active);active=None
        elif kind=='native-boundary' and data.get('stage')=='caption-before-query: '+CAPTION:
            require(active is not None,'Boundary outside ending wait')
            require(type(data['pid']) is int and data['pid']==pid,'Wait PID mismatch')
            require(type(data['handle']) is int and data['handle']>0,'Wait HWND invalid')
            active['windows'].add(data['handle'])
        elif kind=='caption-action-enumeration' and data.get('name')==CAPTION:
            require(active is not None,'Harness enumeration outside ending wait')
    require(active is None,'Unpaired ending wait start')
    require(waits,'Ending wait missing')
    return waits
