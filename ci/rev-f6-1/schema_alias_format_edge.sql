\set ON_ERROR_STOP on
-- Force a reviewed historical phone to retain country-code formatting in source.
-- REV-F6.1 must normalize this source key to the same 9-digit lookup contract.
update public.aos_f5_patient_source_rows_v1
set phone_key='51999000111'
where id=1;
