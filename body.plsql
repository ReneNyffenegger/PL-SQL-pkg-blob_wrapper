create or replace package body blob_wrapper as

  c_temp_dir_name constant varchar2(30) := 'TQ84_TEMP_DIR';

  type file_path_r is record (
    path       varchar2(4000),
    file_name  varchar2(4000));

  function split_file_path(filepath in varchar2) return file_path_r is -- {

    ret file_path_r;
  begin

    ret.path      := regexp_replace(filepath, '(.*)(\\|/).*', '\1');
    ret.file_name := regexp_replace(filepath, '.*(\\|/)(.*)', '\2');

    return ret;

  end split_file_path; -- }

  procedure to_file(dir in varchar2, file in varchar2, lob in blob) is/*{*/
    output_file    utl_file.file_type;
    chunk_size     constant pls_integer := 4096;
    buf            raw                    (4096); -- Must be equal to chunk_size
    written_sofar  pls_integer := 0;              --(avoid PLS-00491: numeric literal required)
    bytes_to_write pls_integer;
    lob_len        pls_integer;

  begin

    lob_len := dbms_lob.getlength(lob);

    output_file := utl_file.fopen(dir, file, 'WB');

    while written_sofar + chunk_size < lob_len loop

      bytes_to_write := chunk_size;
      dbms_lob.read(lob,bytes_to_write,written_sofar+1,buf);
      utl_file.put_raw(output_file,buf);
      written_sofar := written_sofar + chunk_size;

    end loop;

    bytes_to_write := lob_len-written_sofar;
    dbms_lob.read(lob,bytes_to_write,written_sofar+1,buf);
    utl_file.put_raw(output_file,buf);

    utl_file.fclose(output_file);

  end to_file;/*}*/

  procedure to_file(filepath in varchar2, lob in blob) is -- {
    file_path_ file_path_r;

    procedure create_directory(dir in varchar2) is -- {
      pragma autonomous_transaction;
    begin

      execute immediate 'create directory ' || c_temp_dir_name || ' as ''' || dir || '''';

    exception when others then
      if sqlcode = -1031 then -- insufficient privileges
        raise_application_error(-20800, 'Could not create directory, needs ''grant create any directory to ... privilege''');
      end if;

    end create_directory; -- }

    procedure drop_directory is -- {
      pragma autonomous_transaction;
    begin

      execute immediate 'drop directory ' || c_temp_dir_name;

    exception when others then
      if sqlcode = -1031 then -- insufficient privileges
        raise_application_error(-20800, 'Could not drop directory, needs ''grant drop any directory to ... privilege''');
      end if;

    end drop_directory; -- }

  begin

    file_path_ := split_file_path(filepath);

    create_directory(file_path_.path);

    to_file(c_temp_dir_name, file_path_.file_name, lob);

    drop_directory;

  end to_file; -- }

  function from_file(dir in varchar2, file in varchar2) return blob is/*{*/
    ret blob;
  begin
    dbms_lob.createTemporary(ret, true);
    from_file(dir, file, ret);
    return ret;
  end from_file;/*}*/

  procedure from_file(dir in varchar2, file in varchar2, b in out blob) is /*{*/
    input_file    utl_file.file_type;
    chunk_size    constant pls_integer := 4096;
    buf           raw                    (4096); -- Must be equal to chunk_size
    read_sofar    pls_integer := 0;              --(avoid PLS-00491: numeric literal required)
    bytes_to_read pls_integer;
  begin

    input_file := utl_file.fopen(dir, file, 'RB');

    begin loop

      utl_file.get_raw(input_file, buf, chunk_size);
      bytes_to_read := length(buf) / 2; -- strange and unexplanable!
      dbms_lob.write(b, bytes_to_read, read_sofar+1, buf);
      read_sofar := read_sofar + bytes_to_read;

    -- utl_file raises no_data_found when unable to read
    end loop; exception when no_data_found then null; end;

    utl_file.fclose(input_file);

  end from_file;/*}*/

  function substr(b in blob, length_ in number, start_ in number, chunk_size in number := 30000) return blob is -- {
     ret       blob;

     offset_   number;
     amount_   number;

     nof_pieces number;
  begin
     dbms_lob.createTemporary(ret, true);

     nof_pieces := 1+trunc( (length_ - 1) / chunk_size);

     for piece in 0 .. nof_pieces -1 loop

--     dbms_output.put_line('  piece: ' || piece);

       offset_ := start_ + piece * chunk_size;

       if (piece+1) * chunk_size > length_ then
          amount_ := mod(length_, chunk_size);
--        dbms_output.put_line(' >: amount_: ' || amount_);
       else
          amount_ := chunk_size;
--        dbms_output.put_line(' <: amount_: ' || amount_);
       end if;

--     dbms_output.put_line('length_: ' || length_);
--     dbms_output.put_line('amount_: ' || amount_);
--     dbms_output.put_line('offset_: ' || offset_);

       dbms_lob.append(ret, dbms_lob.substr(b, amount_, offset_));

     end loop;

     return ret;

  end substr; -- }

end blob_wrapper;
/
