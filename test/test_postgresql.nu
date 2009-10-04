;; test_postgresql.nu
;;  tests for the Nu PostgreSQL wrapper.
;;
;;  Copyright (c) 2008 Tim Burks, Neon Design Technology, Inc.

(load "NuPostgreSQL")

(class TestPostgreSQL is NuTestCase
     
     (- testFamily is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m query:"drop table if exists triples"))
        (set result (m query:<<-END
        create table triples (
         id serial primary key,
        	subject text,
        	object text,
        	relation text)					
        END))
        (set result (m query:<<-END
        insert into triples ( subject, object, relation )
        values 
        ('homer', 'marge', 'wife'),
        ('homer', 'bart', 'son'),
        ('homer', 'lisa', 'daughter'),
        ('marge', 'homer', 'husband'),
        ('marge', 'lisa', 'daughter'),
        ('marge', 'bart', 'son'),
        ('bart', 'homer', 'father'),
        ('bart', 'marge', 'mother'),
        ('bart', 'lisa', 'sister'),
        ('lisa', 'homer', 'father'),
        ('lisa', 'marge', 'mother'),
        ('lisa', 'bart', 'brother')
        END))
        (set result (m query:"select * from triples"))
        (assert_equal 12 (result tupleCount))
        (set resultArray (m queryAsArray:"select * from triples where subject = 'homer'"))
        (assert_equal 3 (resultArray count))
        (resultArray each:
             (do (d)
                 (case (d valueForKey:"object")
                       ("bart"   (assert_equal "son"      (d valueForKey:"relation")))
                       ("lisa"   (assert_equal "daughter" (d valueForKey:"relation")))
                       ("marge"  (assert_equal "wife"     (d valueForKey:"relation")))
                       (else nil))))
        
        (set result (m queryAsArray:"select object from triples where subject = 'homer' and relation = 'son'"))
        (assert_equal 1 (result count))
        (set row (result 0))
        (assert_equal "bart" (row "object"))
        
        (set result (m queryAsValue:"select * from triples where subject = 'homer' and relation = 'wife'"))
        (assert_equal "marge" (result "object"))
        
        (set result (m queryAsDictionary:"select * from triples where subject = 'homer'" withKey:"relation"))
        (assert_equal "lisa" ((result "daughter") "object"))
        
        (set result (m queryAsArray:"select * from triples"))
        (assert_equal 12 (result count))
        
        ;; some empty queries
        
        (set result (m queryAsValue:"select * from triples where subject = 'homer' and relation = 'husband'"))
        (assert_equal nil result)
        
        (set result (m queryAsDictionary:"select * from triples where subject = 'homer' and relation = 'husband'" withKey:"relation"))
        (assert_equal 0 (result count))
        
        (set result (m queryAsArray:"select * from triples where subject = 'homer' and relation = 'husband'"))
        (assert_equal 0 (result count))
        (m query:"drop table triples"))
     
     (- testInsert is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m query:"drop table if exists cities"))
        (set result (m query:<<-END
        create table cities (
          id SERIAL PRIMARY KEY,
          city text,
          nation text)					
        END))
        (set result (m query:"insert into cities (city, nation) values ($1, $2)" withArguments:(array "San Francisco" "United States")))
        (set result (m query:"insert into cities (city, nation) values ($1, $2)" withArguments:(array "Tokyo" "Japan")))
        (set result (m query:"insert into cities (city, nation) values ($1, $2)" withArguments:(array "Bangalore" "India")))
        (set result (m query:"insert into cities (city, nation) values ($1, $2)" withArguments:(array "Copenhagen" "Denmark")))      
        (set result (m query:"select * from cities"))
        (assert_equal 4 (result tupleCount))
        (set result ((m queryAsDictionary:"select * from cities" withKey:"nation")))
        (assert_equal "Tokyo" ((result "Japan") "city"))
        (m query:"drop table cities"))
     
     (- testUpdate is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m query:"drop table if exists cities"))
        (set result (m query:<<-END
          create table cities (
            id SERIAL PRIMARY KEY,
          	city text,
          	nation text)					
          END))
        (set result (m query:<<-END
          insert into cities ( id, city, nation )
          values 
          (1, 'San Francisco', 'United States'),
          (2, 'Tokyo', 'Japan'),
          (3, 'Bangalore', 'India'),
          (4, 'Copenhagen', 'Denmark')
          END))
        (set result (m query:"select * from cities"))
        (assert_equal 4 (result tupleCount))
        (set result (m query:"update cities set city = $1 where id = $2" withArguments:(array "Yokohama" 2)))
        (set result (m queryAsValue:"select * from cities where id = 2"))
        (assert_equal "Yokohama" (result "city"))
        (assert_equal "Japan" (result "nation"))
        (set result (m query:"update cities set city = $1, nation = $2 where id = $3" withArguments:(array "London" "England" 4)))
        (set result (m queryAsValue:"select * from cities where id = 4"))
        (assert_equal "London" (result "city"))
        (assert_equal "England" (result "nation"))
        (m query:"drop table cities"))
     
     (- testIntrospectiveInsertsAndUpdates is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m query:"drop table if exists cities"))
        (set result (m query:<<-END
          create table cities (
               id SERIAL PRIMARY KEY,
            	city text,
            	nation text,
            	updated_at timestamp,
            	created_at timestamp)					
END))
        (set san_francisco
             (m insertDictionary:(dict city:"San Francisco" nation:"United States") intoTable:"cities" returnId:YES))
        (set tokyo
             (m insertDictionary:(dict city:"Tokyo" nation:"Japan") intoTable:"cities" returnId:YES))
        (set bangalore
             (m insertDictionary:(dict city:"Bangalore" nation:"India") intoTable:"cities" returnId:YES))
        (set copenhagen
             (m insertDictionary:(dict city:"Copenhagen" nation:"Denmark") intoTable:"cities" returnId:YES))
        (set cities (m queryAsDictionary:"select * from cities" withKey:"id"))
        (assert_equal "San Francisco" ((cities san_francisco) "city"))
        (assert_equal "Tokyo" ((cities tokyo) "city"))
        (assert_equal "Bangalore" ((cities bangalore) "city"))
        (assert_equal "Copenhagen" ((cities copenhagen) "city"))
        
        (set city (cities copenhagen))
        (city setObject:"Yokohama" forKey:"city")
        (city setObject:"Japan" forKey:"nation")
        (m updateTable:"cities" withDictionary:city)
        
        (set city (m queryAsValue:"select * from cities where id = $1" withArguments:(array copenhagen)))
        (assert_equal "Yokohama" (city "city"))
        (assert_equal "Japan" (city "nation"))
        (assert_equal copenhagen (city "id"))
        (m query:"drop table cities")))
