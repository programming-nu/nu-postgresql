;; test_postgresql.nu
;;  tests for the Nu PostgreSQL wrapper.
;;
;;  Copyright (c) 2008 Tim Burks, Neon Design Technology, Inc.

(load "NuPostgreSQL")

(class PGFieldType (ivar-accessors))
(class PGResult (ivar-accessors))
(class PGConnection (ivar-accessors))

(class TestPostgreSQL is NuTestCase
     
     (- (id) testFamily is
        (set c ((PGConnection alloc) init))
        (c setConnectionInfo:(dict user:"postgres" dbname:"test"))
        (set result (c connect))
        (assert_equal 1 result)                
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
        (set result (c exec:"drop table triples"))))
