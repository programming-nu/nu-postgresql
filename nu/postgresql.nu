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

(class PGFieldType (ivar-accessors))

(class PGResult (ivar-accessors)
     (- (id) dictionaryForTuple:(int)i is
        (set d (dict))
        ((self fieldTypes) eachWithIndex:
         (do (ft j)
             (set key (ft name))
             (set value (self valueOfTuple:i field:j))
             (d setObject:value forKey:key)))
        d))

(class PGConnection (ivar-accessors)
     ;; Perform a query and return the result as an array of dictionaries.
     ;; Each row of a query result is returned as a dictionary.
     (- (id) queryAsArray:(id) query is
        (set result (self exec:query))
        (if result
            (then (set a (array))
                  ((result tupleCount) times:
                   (do (i)
                       (a addObject: (result dictionaryForTuple:i))))
                  a)
            (else nil)))
     
     ;; Perform a query and return the result as a dictionary of dictionaries,
     ;; with the top-level dictionary keyed by the specified key.
     ;; Each row of a query result is returned as a dictionary.
     (- (id) queryAsDictionary:(id) query withKey:(id) key is
        (set result (self exec:query))
        (if result
            (then (set d (dict))
                  ((result tupleCount) times:
                   (do (i)
                       (set row (result dictionaryForTuple:i))
                       (d setValue:row forKey:(row valueForKey:key))))
                  d)
            (else nil)))
     
     ;; Perform a query and return a single result as a dictionary.
     ;; Returns nil if multiple matches exist.
     (- (id) queryAsValue:(id) query is
        (set result (self exec:query))
        (if (eq (result tupleCount) 1)
            (then (result dictionaryForTuple:0))
            (else nil))))
