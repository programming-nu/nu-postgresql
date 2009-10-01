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
     (ivars)
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
        (result value)))
