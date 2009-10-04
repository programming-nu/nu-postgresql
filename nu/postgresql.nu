;; @file       postgresql.nu
;; @discussion Nu components of NuPostgreSQL.
;;
;; @copyright  Copyright (c) 2008 Tim Burks, Neon Design Technology, Inc.
;;
;;   Licensed under the Apache License, Version 2.0 (the "License");
;;   you may not use this file except in compliance with the License.
;;   You may obtain a copy of the License at
;;
;;       http://www.apache.org/licenses/LICENSE-2.0
;;
;;   Unless required by applicable law or agreed to in writing, software
;;   distributed under the License is distributed on an "AS IS" BASIS,
;;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;   See the License for the specific language governing permissions and
;;   limitations under the License.

(class PGFieldType (ivar-accessors)
     (- (id) name is @name)) ;; required to avoid GNUstep conflict

(class PGResult (ivar-accessors)
     (- (id) array is
        (set a (array))
        ((self tupleCount) times:
         (do (i)
             (a addObject: (self dictionaryForTuple:i))))
        a)
     
     (- (id) dictionaryWithKey:(id) key is
        (set d (dict))
        ((self tupleCount) times:
         (do (i)
             (set row (self dictionaryForTuple:i))
             (d setValue:row forKey:(row valueForKey:key))))
        d)
     
     (- (id) value is
        (if (eq (self tupleCount) 1)
            (then (self dictionaryForTuple:0))
            (else nil)))
     
     (- (id) dictionaryForTuple:(int)i is
        (set d (dict))
        ((self fieldTypes) eachWithIndex:
         (do (ft j)
             (set key (ft name))
             (set value (self valueOfTuple:i field:j))
             (if value
                 (d setObject:value forKey:key))))
        d))

(class PGConnection
     (ivar-accessors)
     
     ;; Perform a query and return the result as an array of dictionaries.
     ;; Each row of a query result is returned as a dictionary.
     (- (id) queryAsArray:(id) query is
        (set result (self query:query))
        (result array))
     
     (- (id) queryAsArray:(id) query withArguments:(id) args is
        (set result (self query:query withArguments:args))
        (result array))
     
     ;; Perform a query and return the result as a dictionary of dictionaries,
     ;; with the top-level dictionary keyed by the specified key.
     ;; Each row of a query result is returned as a dictionary.
     (- (id) queryAsDictionary:(id) query withKey:(id) key is
        (set result (self query:query))
        (result dictionaryWithKey:key))
     
     (- (id) queryAsDictionary:(id) query withArguments:(id) args withKey:(id) key is
        (set result (self query:query withArguments:args))
        (result dictionaryWithKey:key))
     
     ;; Perform a query and return a single result as a dictionary.
     ;; Returns nil if multiple matches exist.
     (- (id) queryAsValue:(id) query is
        (set result (self query:query))
        (result value))
     
     (- (id) queryAsValue:(id) query withArguments:(id) args is
        (set result (self query:query withArguments:args))
        (result value))
     
     ;; helper function
     (set query-parms-for-count
          (let (cache (dict))
               (do (n)
                   (if (set result (cache n)) (return result))
                   (set result "")
                   (n times:
                      (do (i)
                          (if (> i 0) (result appendString:", "))
                          (result appendString:(+ "$" (+ i 1)))))
                   (cache setObject:result forKey:n)
                   result)))
     
     ;; extracts a database schema so that we can use it to construct insert and update statements
     (- extractSchema is
        (set @schema (dict))
        (set tables ((self queryAsArray:"select tablename from pg_tables where schemaname = 'public'")
                     map:(do (table) (table "tablename"))))
        (tables each:
                (do (table)
                    (set tableDescription
                         (self queryAsValue:"select reltype,relfilenode from pg_class where relname = $1"
                               withArguments:(array table)))
                    (set columns (array))
                    (set columnDescriptions
                         (self queryAsArray:"select attname,atttypid from pg_attribute where attrelid = $1 and attnum > 0"
                               withArguments:(array (tableDescription "relfilenode"))))
                    (columnDescriptions each:
                         (do (columnDescription)
                             (set type (self queryAsValue:"select * from pg_type where typelem = $1 or typrelid = $1"
                                             withArguments:(array (columnDescription "atttypid"))))
                             (columns << (dict name:(columnDescription "attname") type:(type "typname")))))
                    (@schema setObject:columns forKey:table)))
        @schema)
     
     ;; Helper that produces arrays of column names and values for a dictionary and database table
     ;; optionally it will exclude the column named "id"
     (- (id) getFieldsAndValuesForDictionary:(id) object table:(id)table excludeId:(id) excludeId is
        (set fields (array))
        (set values (array))
        (set columns (@schema table))
        (columns each:
                 (do (column)
                     (set key (column "name"))
                     (if (or (not excludeId)
                             (!= key "id"))
                         (if (set value (object objectForKey:(key stringValue)))
                             (fields << (key stringValue))
                             (values << value)))))
        (list fields values))
     
     ;; Insert a dictionary into a table by introspecting the table and matching
     ;; dictionary keys with table columns. Optionally returns the id of the new row.
     ;; Automatically manages created_at and updated_at timestamps.
     (- (id) insertDictionary:(id) object intoTable:(id) table returnId:(BOOL) returnId is
        (unless @schema (self extractSchema))
        (set fv (self getFieldsAndValuesForDictionary:object table:table excludeId:NO))
        (set fields (fv car))
        (set values (fv cdar))
        
        (set timestamp_fields "")
        (set timestamp_values "")
        (unless (object objectForKey:"created_at")
                (set timestamp_fields (+ timestamp_fields ", created_at"))
                (set timestamp_values (+ timestamp_values ", current_timestamp")))
        (unless (object objectForKey:"updated_at")
                (set timestamp_fields (+ timestamp_fields ", updated_at"))
                (set timestamp_values (+ timestamp_values ", current_timestamp")))
        
        (set query
             (+ "insert into " table " ("
                (fields componentsJoinedByString:", ")
                timestamp_fields
                ") values ("
                (query-parms-for-count (fields count))
                timestamp_values
                ")"))
        
        (self query:"begin transaction")
        (self query:query withArguments:values)
        (if returnId
            (set result
                 ((self queryAsValue:( + "select currval('" table "_id_seq')")) "currval")))
        (self query:"commit transaction")
        (if returnId (then result) (else nil)))
     
     ;; Update a table with a given dictionary by introspecting the table columns
     ;; and matching them with dictionary keys. This assumes that the dictionary
     ;; and table row contain unique primary keys named "id". The value of this
     ;; key is used in the SQL update statement. Automatically manages updated_at
     ;; timestamps.
     (- (id) updateTable:(id) table withDictionary:(id) object is
        (unless @schema (self extractSchema))
        (set fv (self getFieldsAndValuesForDictionary:object table:table excludeId:YES))
        (set fields (fv car))
        (set values (fv cdar))
        
        (set timestamp_update "")
        (unless (object objectForKey:"updated_at")
                (set timestamp_update ", updated_at = current_timestamp"))
        
        (set assignmentArray (array))
        (fields eachWithIndex:
                (do (field i)
                    (assignmentArray addObject:(+ field " = $" (+ i 1)))))
        (set assignments (assignmentArray componentsJoinedByString:", "))
        
        (set query (+ "update " table " set " assignments timestamp_update " where id = $" (+ 1 (assignmentArray count))))
        (values addObject:(object "id"))
        (self query:query withArguments:values)))

