import os
from contextlib import closing
import socket
import json
import boto3
from boto3.dynamodb.conditions import Key


DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
DYNAMODB_CONFIG_ID = os.environ['DYNAMODB_CONFIG_ID']
ALARM_ARNS = os.environ['ALARM_ARNS']

NS='availability-checks-lambda'
DIMENSION='target'


def get_config_from_dynamodb(table_name, config_id):
    """
    Returns the monitors config from the dynamodb table
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    scan_kwargs = {
       'FilterExpression': Key('configId').eq(config_id)
    }
    response = table.scan(**scan_kwargs)
    config = response['Items']

    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        config.extend(response['Items'])
    return config

def put_metric_data(namespace, metricname, unit, value, dimensions):
    """
    """
    cw = boto3.client('cloudwatch')
    cw.put_metric_data(
      MetricData=[
        {
            'MetricName': metricname,
            'Dimensions':dimensions,
            'Unit': unit,
            'Value': value
        },
      ],
      Namespace=namespace
    )

def put_metric_alarm(alarmname, alarmdesc, namespace, metricname, dimensions, alarmactions):
    """
    """
    cw = boto3.client('cloudwatch')
    if len(alarmactions) > 0:
        actionsenabled = True

    
    cw.put_metric_alarm(
      AlarmName=alarmname,
      ComparisonOperator='LessThanThreshold',
      EvaluationPeriods=1,
      MetricName=metricname,
      Namespace=namespace,
      Period=300,
      Statistic='Maximum',
      Threshold=1.0,
      ActionsEnabled=actionsenabled,
      AlarmActions=alarmactions,
      OKActions=alarmactions,
      AlarmDescription=alarmdesc,
      Dimensions=dimensions
    )

def port_check(host, port):
    """
    """
    try:
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
            s.settimeout(5)
            print("connecting to {}:{}".format(host,port))
            rc = s.connect_ex((host, port))
    except:
        rc = 1
    success = (rc == 0)
    print("connection successful: {}".format(success))
    return success

def lambda_handler(event, context):

    config = get_config_from_dynamodb(DYNAMODB_TABLE, DYNAMODB_CONFIG_ID)

    # process the config probes
    for probe in config:
      target, metric, host, port = probe['target'], probe['type'], probe['host'], probe['port']
      dimension =  [{ "Name": DIMENSION, "Value": "{}_{}".format(target, port) }]
      # test connectivity to the port
      status = port_check(host,int(port))

      # write the result to cloudwatch
      put_metric_data(
          NS,
          metric,
          'None',
          int(status),
          dimension
      )

      # create the cloudwatch alarm
      print("creating alarm for: {}/{}/{}_{}".format(NS, metric, target, port))
    
      alarmname = '{}/{}/{}_{}'.format(NS, metric, target, port)
      alarmdesc = "port check on {}:{}".format(target, port)
      alarmarns = [i for i in ALARM_ARNS.split(",") if i]
      put_metric_alarm(
          alarmname,
          alarmdesc,
          NS,
          metric,
          dimension,
          alarmarns
      )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
