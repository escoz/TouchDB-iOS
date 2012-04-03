//
//  TDJSON.m
//  TouchDB
//
//  Created by Jens Alfke on 2/27/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "TDJSON.h"

#if !USE_NSJSON
#import "JSONKit.h"
#endif


@implementation TDJSON


#if USE_NSJSON


+ (NSData *)dataWithJSONObject:(id)object
                       options:(TDJSONWritingOptions)options
                         error:(NSError **)error
{
    if ((options & TDJSONWritingAllowFragments)
            && ![object isKindOfClass: [NSDictionary class]]
            && ![object isKindOfClass: [NSArray class]]) {
        // NSJSONSerialization won't write fragments, so if I get one wrap it in an array first:
        object = [[NSArray alloc] initWithObjects: &object count: 1];
        NSData* json = [super dataWithJSONObject: object 
                                         options: (options & ~TDJSONWritingAllowFragments)
                                           error: nil];
        [object release];
        return [json subdataWithRange: NSMakeRange(1, json.length - 2)];
    } else {
        return [super dataWithJSONObject: object options: options error: error];
    }
}


#else // not USE_NSJSON

+ (NSData *)dataWithJSONObject:(id)obj
                       options:(TDJSONWritingOptions)opt
                         error:(NSError **)error
{
    Assert(obj);
    return [obj JSONDataWithOptions: 0 error: error];
}


+ (id)JSONObjectWithData:(NSData *)data
                 options:(TDJSONReadingOptions)opt
                   error:(NSError **)error
{
    Assert(data);
    if (opt & (TDJSONReadingMutableContainers | TDJSONReadingMutableLeaves))
        return [data mutableObjectFromJSONDataWithParseOptions: 0 error: error];
    else
        return [data objectFromJSONDataWithParseOptions: 0 error: error];
}


#endif // USE_NSJSON


+ (NSString*) stringWithJSONObject:(id)obj
                           options:(TDJSONWritingOptions)opt
                             error:(NSError **)error
{
    return [[self dataWithJSONObject: obj options: opt error: error] my_UTF8ToString];
}


+ (NSData*) appendDictionary: (NSDictionary*)dict
        toJSONDictionaryData: (NSData*)json
{
    if (!dict.count)
        return json;
    NSData* extraJson = [self dataWithJSONObject: dict options: 0 error: nil];
    if (!extraJson)
        return nil;
    size_t jsonLength = json.length;
    size_t extraLength = extraJson.length;
    CAssert(jsonLength >= 2);
    CAssertEq(*(const char*)json.bytes, '{');
    if (jsonLength == 2)  // Original JSON was empty
        return extraJson;
    NSMutableData* newJson = [NSMutableData dataWithLength: jsonLength + extraLength - 1];
    if (!newJson)
        return nil;
    uint8_t* dst = newJson.mutableBytes;
    memcpy(dst, json.bytes, jsonLength - 1);                          // Copy json w/o trailing '}'
    dst += jsonLength - 1;
    *dst++ = ',';                                                     // Add a ','
    memcpy(dst, (const uint8_t*)extraJson.bytes + 1, extraLength - 1);  // Add "extra" after '{'
    return newJson;
}


@end
