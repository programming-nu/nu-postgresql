#import <Foundation/Foundation.h>
#import <Nu/Nu.h>
#include "libpq-fe.h"

@interface PGFieldType : NSObject
{
    NSString *name;
    int index;
    int type;
    int size;
    int offset;
}

@end

@implementation PGFieldType

- (id) initWithResult:(PGresult *) r index:(int) i
{
    [self init];
    name = [[NSString alloc] initWithCString:PQfname(r,i) encoding:NSUTF8StringEncoding];
    index = i;
    type = PQftype(r,i);
    size = PQfsize(r,i);
    offset = PQfmod(r,i);
    return self;
}

@end

@interface PGResult : NSObject
{
    PGresult *result;
    int tuples;
    int fields;
    NSMutableArray *fieldTypes;
}

@end

@implementation PGResult
- (id) initWithResult:(PGresult *)r
{
    [self init];
    result = r;
    switch (PQresultStatus(result)) {
        case PGRES_TUPLES_OK:
        {
            // build the recordset
            tuples = PQntuples(result);
            //NSLog(@"Query succeeded, %d rows affected.", tuples);
            fields = PQnfields(result);
            fieldTypes = [[NSMutableArray alloc] init];
            for (int i = 0; i < fields; i++) {
                [fieldTypes addObject:[[PGFieldType alloc] initWithResult:result index:i]];
            }
            break;
        }
        case PGRES_COMMAND_OK:
        {
            //NSLog(@"Query succeeded.");
            break;
        }
        case PGRES_EMPTY_QUERY:
        {
            NSLog(@"Empty query");
            break;
        }
        case PGRES_COPY_OUT:
        case PGRES_COPY_IN:
        case PGRES_BAD_RESPONSE:
        case PGRES_NONFATAL_ERROR:
        case PGRES_FATAL_ERROR:
        default:
        {
            NSLog(@"PostgreSQL Error: %s", PQresultErrorMessage(result));
            break;
        }
    }
    return self;
}

- (void) dealloc
{
    [fieldTypes release];
    PQclear(result);
    [super dealloc];
}

- (int) tupleCount
{
    return PQntuples(result);
}

- (id) valueOfTuple:(int) t field:(int) f
{
    if (PQgetisnull(result, t, f))
        return nil;
    int length = PQgetlength(result, t, f);
    const char *value = PQgetvalue(result, t, f);
    return [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
}

- (NSString *) status
{
    switch (PQresultStatus(result)) {
        case PGRES_TUPLES_OK: return @"TUPLES OK";
        case PGRES_COMMAND_OK: return @"COMMAND OK";
        case PGRES_EMPTY_QUERY: return @"EMPTY QUERY";
        case PGRES_COPY_OUT: return @"COPY OUT";
        case PGRES_COPY_IN: return @"COPY IN";
        case PGRES_BAD_RESPONSE: return @"BAD RESPONSE";
        case PGRES_NONFATAL_ERROR: return @"NONFATAL ERROR";
        case PGRES_FATAL_ERROR: return @"FATAL ERROR";
        default: return @"STATUS UNKNOWN";
    }
}

- (NSString *) errorMessage
{
    switch (PQresultStatus(result)) {
        case PGRES_BAD_RESPONSE:
        case PGRES_NONFATAL_ERROR:
        case PGRES_FATAL_ERROR:
            return [[NSString stringWithCString:PQresultErrorMessage(result) encoding:NSUTF8StringEncoding]
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        default:
            return nil;
    }
}

@end

@interface PGConnection : NSObject
{
    PGconn *connection;
    NSMutableDictionary *connectionInfo;
}

@end

void notice_processor(void *arg, const char *message)
{
    NSLog(@"PostgreSQL: %s", message);
}

@implementation PGConnection

+ (void) load
{
    static int initialized = 0;
    if (!initialized) {
        initialized = 1;
        [Nu loadNuFile:@"postgresql" fromBundleWithIdentifier:@"nu.programming.nupostgresql" withContext:nil];
    }
}


- (id) init
{
    [super init];
    connectionInfo = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) dealloc
{
    [connectionInfo release];
    [super dealloc];
}

- (NSString *) connectionString
{
    NSArray *allowedKeys =
        [NSArray arrayWithObjects:@"host", @"hostaddr", @"port", @"dbname", @"user",
        @"password", @"connect_timeout", @"options", @"tty", @"sslmode", @"requiressl",
        @"krbsrvname", @"service", nil];

    NSMutableString *connectionString = [NSMutableString string];
    for (id key in [connectionInfo allKeys]) {
        id value;
        if ((value = [connectionInfo objectForKey:key])) {
            [connectionString appendFormat:@" %@='%@'", key, value];
        }
    }
    return connectionString;
}

- (BOOL) connect
{
    NSString *connectionString = [self connectionString];
    connection = PQconnectdb([connectionString cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!connection) {
        NSLog(@"Connection failed. Unable to allocate connection.");
        return NO;
    }
    if (PQstatus(connection) == CONNECTION_BAD) {
        NSLog(@"Connection failed. %s", PQerrorMessage(connection));
        PQfinish(connection);
        connection = nil;
        return NO;
    }
    PQsetNoticeProcessor(connection, notice_processor, self);
    //NSLog(@"Connection succeeded.");
    return YES;
}

- (void) close
{
    PQfinish(connection);
}

- (PGResult *) exec:(NSString *)command
{
    if (connection == nil) {
        NSLog(@"There is no connection to a database.");
        return nil;
    }
    PGresult *result = PQexec(connection, [command cStringUsingEncoding:NSUTF8StringEncoding]);
    return [[[PGResult alloc] initWithResult:result] autorelease];
}

@end
