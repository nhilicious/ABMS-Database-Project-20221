--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE admin1;
ALTER ROLE admin1 WITH NOSUPERUSER INHERIT CREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:d5fL/YTjEH8eQ3BKfu/eDQ==$lMuAF7TnHk89WbsmDjZxXCgHyTdbFywhVMl8guu+sh4=:B05XmvdvOJJP75drQmWMOGEtz3cdKGhiiR0XviB5O1U=';
CREATE ROLE manager1;
ALTER ROLE manager1 WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:PEkSMVtXWbOs3qZMYQFmtg==$1zN3C5PaqLc/hzGhxoar0YfMO62C9LoF7Xdz5mUXg/0=:8SF3reSaMjiCJ4b0l+WHGYSOYJ0AnaLp8s6mbWt8+Sk=';
CREATE ROLE manager2;
ALTER ROLE manager2 WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:4jgbxKllKuh3E/02S0lLhA==$G6IJH1ltNQ1OvD+151TVNSd/hkgrirQ/9c2lw+CAoMg=:VHp7kT9qcfZnkc1W59jHD8D39SUFGa8f7n1dWy4cPYU=';
CREATE ROLE manager3;
ALTER ROLE manager3 WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:84We1KF1K5gT6gIH5LJ6rw==$KEsM+okVnOdg5G54iRc0M7gk+JAIVYtXO7Dy1airoFM=:M72qJblKLFl6h08fsqiJYglVwDBSZsSPDW4dHfoY940=';
CREATE ROLE manager_group;
ALTER ROLE manager_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:sXPXWnLTdPXfHHEOMS7xtA==$VGIgxv7vwvARLCxxyfJzqa+CHsBlnrTpg63IGebZfKE=:wJuTxyxClGbKLJxuDqL+L9qQt+bbLS1D/vxI20RYPTE=';
CREATE ROLE tenant1;
ALTER ROLE tenant1 WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:E3SP+rLSgXGoUx9WucSnEw==$J7vBqCiiadrPcJPXbNgnFXHwOCEuPeWoJYJk7SxtsSk=:a8inZqFtbOA7HwMR7gYCO8eqhI14qP8HmCsMb/zivZA=';
CREATE ROLE tenant_group;
ALTER ROLE tenant_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

--
-- User Configurations
--


--
-- Role memberships
--

GRANT manager_group TO manager1 GRANTED BY postgres;
GRANT manager_group TO manager2 GRANTED BY postgres;
GRANT manager_group TO manager3 GRANTED BY postgres;
GRANT tenant_group TO tenant1 GRANTED BY postgres;




--
-- PostgreSQL database cluster dump complete
--
