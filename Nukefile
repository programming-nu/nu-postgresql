;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))

(set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))

(set pg_include_dir ((NSString stringWithShellCommand:"pg_config --includedir") chomp))
(set pg_lib_dir ((NSString stringWithShellCommand:"pg_config --libdir") chomp))

(case SYSTEM
      ("Darwin"
               (set @cflags "-g -fobjc-gc -std=gnu99 -DDARWIN -I#{pg_include_dir}")
               (set @ldflags "-framework Foundation -framework Nu -lpq -L#{pg_lib_dir}"))
      ("Linux"
              (set @arch (list "i386"))
              (set @cflags "-g -std=gnu99 -DLINUX -I/usr/include/GNUstep/Headers -I/usr/local/include -I#{pg_include_dir} -fconstant-string-class=NSConstantString ")
              (set @ldflags "-L/usr/local/lib -lNu -lpq -L#{pg_lib_dir}"))
      (else nil))

;; framework description
(set @framework "NuPostgreSQL")
(set @framework_identifier "nu.programming.nupostgresql")
(set @framework_creator_code "????")

(compilation-tasks)
(framework-tasks)

(task "clobber" => "clean" is
      (SH "rm -rf #{@framework_dir}"))

(task "default" => "framework")

(task "doc" is (SH "nudoc"))

(task "install" => "framework" is
      (SH "sudo rm -rf /Library/Frameworks/#{@framework}.framework")
      (SH "sudo cp -rp #{@framework}.framework /Library/Frameworks/#{@framework}.framework"))

(task "test" => "framework" is
      (SH "nutest test/test_*.nu"))
