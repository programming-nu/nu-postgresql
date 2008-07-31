;; test_postgresql.nu
;;  tests for the Nu PostgreSQL wrapper.
;;
;;  Copyright (c) 2008 Tim Burks, Neon Design Technology, Inc.

(load "NuPostgreSQL")

(class TestPostgreSQL is NuTestCase
     
     (- (id) testFamily is
        (set c ((PGConnection alloc) init))
        (c setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (c connect))
        (assert_equal 1 result)
        (set result (c exec:"drop table if exists triples"))
        (set result (c exec:<<-END
create table triples (
	subject text,
	object text,
	relation text)					
END))
        (set result (c exec:<<-END
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
        (set result (c exec:"select * from triples"))
        (assert_equal 12 (result tupleCount))
        (set result (c exec:"select * from triples where subject = 'homer'"))
        (assert_equal 3 (result tupleCount))
        (set result (c exec:"select object from triples where subject = 'homer' and relation = 'son'"))
        (assert_equal 1 (result tupleCount))
        (assert_equal "bart" (result valueOfTuple:0 field:0))
        (set result (c exec:"drop table triples")))
     
     
     
     (- testFamily2 is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m exec:"drop table if exists triples"))
        (set result (m exec:<<-END
        create table triples (
        	subject text,
        	object text,
        	relation text)					
        END))
        (set result (m exec:<<-END
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
        (set result (m exec:"select * from triples"))
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
        
        (if NO
            (set result (m exec:"select object from triples where subject = 'homer' and relation = 'son'"))
            (assert_equal 1 (result tupleCount))
            (set row (result nextRowAsArray))
            (assert_equal "bart" (row objectAtIndex:0)))
        
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
        (set result (m exec:"drop table triples")))
       
     (- _testInsert is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m exec:"drop table if exists cities"))
        (set result (m exec:<<-END
        create table cities (
          id SERIAL PRIMARY KEY,
          city text,
          nation text)					
        END))
        (set result (m insertRowInTable:"cities" withDictionary:(dict city:"San Francisco" nation:"United States")))
        (set result (m insertRowInTable:"cities" withDictionary:(dict city:"Tokyo" nation:"Japan")))
        (set result (m insertRowInTable:"cities" withDictionary:(dict city:"Bangalore" nation:"India")))
        (set result (m insertRowInTable:"cities" withDictionary:(dict city:"Copenhagen" nation:"Denmark")))
        (set result (m exec:"select * from cities"))
        (assert_equal 4 (result tupleCount))
        (set result ((m queryAsDictionary:"select * from cities" withKey:"nation")))
        (assert_equal "Tokyo" ((result "Japan") "city")))
     
     (- _testUpdate is
        (set m ((PGConnection alloc) init))
        (m setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (m connect))
        (assert_equal 1 result)
        (set result (m exec:"drop table if exists cities"))
        (set result (m exec:<<-END
          create table cities (
            id integer,
          	city text,
          	nation text)					
          END))
        (set result (m exec:<<-END
          insert into cities ( id, city, nation )
          values 
          (1, 'San Francisco', 'United States'),
          (2, 'Tokyo', 'Japan'),
          (3, 'Bangalore', 'India'),
          (4, 'Copenhagen', 'Denmark')
          END))
        (set result (m exec:"select * from cities"))
        (assert_equal 4 (result tupleCount))
        (set result (m updateTable:"cities" withDictionary:(dict city:"Yokohama") forId:2))
        (set result (m queryAsValue:"select * from cities where id = 2"))
        (assert_equal "Yokohama" (result "city"))
        (assert_equal "Japan" (result "nation"))
        (set result (m updateTable:"cities" withDictionary:(dict city:"London" nation:"England") forId:4))
        (set result (m queryAsValue:"select * from cities where id = 4"))
        (assert_equal "London" (result "city"))
        (assert_equal "England" (result "nation"))))



