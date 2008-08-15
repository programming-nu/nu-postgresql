#import <Foundation/Foundation.h>
#import <Nu/Nu.h>
#include "libpq-fe.h"
#include "ecpgtype.h"

const char *nameOfType(enum ECPGttype code)
{
    switch (code) {
        case ECPGt_char: return "char";
        case ECPGt_unsigned_char: return "unsigned char";
        case ECPGt_short: return "short";
        case ECPGt_unsigned_short: return "unsigned short";
        case ECPGt_int: return "int";
        case ECPGt_unsigned_int: return "unsigned int";
        case ECPGt_long: return "long";
        case ECPGt_unsigned_long: return "unsigned long";
        case ECPGt_long_long: return "long long";
        case ECPGt_unsigned_long_long: return "unsigned long long";
        case ECPGt_bool: return "bool";
        case ECPGt_float: return "float";
        case ECPGt_double: return "double";
        case ECPGt_varchar: return "varchar";
        case ECPGt_varchar2: return "varchar2";
        case ECPGt_numeric: return "numeric";     /* this is a decimal that stores its digits in a malloced array */
        case ECPGt_decimal: return "decimal";     /* this is a decimal that stores its digits in a fixed array */
        case ECPGt_date: return "date";
        case ECPGt_timestamp: return "timestamp";
        case ECPGt_interval: return "interval";
        case ECPGt_array: return "array";
        case ECPGt_struct: return "struct";
        case ECPGt_union: return "union";
                                                  /* sql descriptor: return ""; no C variable */
        case ECPGt_descriptor: return "descriptor";
        case ECPGt_char_variable: return "char variable";
        case ECPGt_const: return "const";         /* a constant is needed sometimes */
        case ECPGt_EOIT: return "EOIT";           /* End of insert types. */
        case ECPGt_EORT: return "EORT";           /* End of result types. */
                                                  /* no indicator */
        case ECPGt_NO_INDICATOR: return "no indicator";
    };
    return "";
}

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
    NSMutableSet *queries;
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
    queries = [[NSMutableSet alloc] init];
    return self;
}

- (void) dealloc
{
    [connectionInfo release];
    [queries release];
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

- (PGResult *) query:(id)query withArguments:(id) arguments
{
    if (connection == nil) {
        NSLog(@"There is no connection to a database.");
        return nil;
    }
    const char *cquery = [query cStringUsingEncoding:NSUTF8StringEncoding];
    if (![queries containsObject:query]) {
        PGresult *preparationResult = PQprepare(connection, cquery, cquery, 0, 0);
        [queries addObject:query];
    }
    /*
    else {
        NSLog(@"reusing query %@", query);
    }
    */
    //PGresult *descriptionResult = PQdescribePrepared(connection, cquery);
    /*
    NSLog(@"prepared query expects %d arguments", PQnparams(descriptionResult));
    for (int i = 0; i < PQnparams(descriptionResult); i++) {
        NSLog(@"param %d type %s", i, nameOfType(PQparamtype(descriptionResult, i)));
    }
    */
    int paramCount = [arguments count];
    char **paramValues = (char **) malloc (paramCount * sizeof(char *));
    for (int i = 0; i < paramCount; i++) {
        NSString *stringValue = [[arguments objectAtIndex:i] stringValue];
        paramValues[i] = strdup([stringValue cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    PGresult *result = PQexecPrepared(connection, cquery, paramCount, (const char **) paramValues, 0, 0, 0);
    for (int i = 0; i < paramCount; i++) {
        free(paramValues[i]);
    }
    free(paramValues);
    return [[[PGResult alloc] initWithResult:result] autorelease];
}

- (PGResult *) query:(NSString *)command
{
    if (connection == nil) {
        NSLog(@"There is no connection to a database.");
        return nil;
    }
    PGresult *result = PQexec(connection, [command cStringUsingEncoding:NSUTF8StringEncoding]);
    return [[[PGResult alloc] initWithResult:result] autorelease];
}

- (PGResult *) exec:(NSString *)command
{
    NSLog(@"exec: is deprecated, please use query: instead.");
    return [self query:command];
}

@end
