exec blob_wrapper.to_file('c:\temp\two_params.txt', utl_raw.cast_to_raw('foo bar baz'))

$ &test_dir\compare_files.bat c:\temp\two_params.txt &test_dir\expected\two_params.txt
