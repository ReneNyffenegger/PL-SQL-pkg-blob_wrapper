declare
  blob_ blob;
begin

  select blb into blob_ from tq84_blob_wrapper_test;
  blob_wrapper.to_file('LOB_TEST_DIR', 'circle_from_table.txt', blob_);

end;
/

$ &test_dir\compare_files &test_dir\expected\circle.txt c:\temp\circle_from_table.txt

drop table tq84_blob_wrapper_test;
