;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))

(set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))

(set pg_include_dir ((NSString stringWithShellCommand:"pg_config --includedir") chomp))
(set pg_lib_dir ((NSString stringWithShellCommand:"pg_config --libdir") chomp))

(case SYSTEM
      ("Darwin"
               (set @cflags "-g -std=gnu99 -DDARWIN -I#{pg_include_dir}")
               (set @ldflags "-framework Foundation -framework Nu -lpq -L#{pg_lib_dir}"))
      ("Linux"
              (set @arch (list "i386"))
              (set gnustep_flags ((NSString stringWithShellCommand:"gnustep-config --objc-flags") chomp))
              (set gnustep_libs ((NSString stringWithShellCommand:"gnustep-config --base-libs") chomp))
              (set @cflags "-g -std=gnu99 -DLINUX -I/usr/local/include -I#{pg_include_dir} #{gnustep_flags}")
              (set @ldflags "#{gnustep_libs} -lNu -lpq -luuid -L#{pg_lib_dir}"))
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
