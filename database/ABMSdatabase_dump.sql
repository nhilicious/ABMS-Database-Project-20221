--
-- PostgreSQL database dump
--

-- Dumped from database version 15.0
-- Dumped by pg_dump version 15.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: available_apartment(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.available_apartment() RETURNS TABLE(building_id integer, apartment_id integer, apartment_floor integer, apartment_name character varying, area_total double precision, area_bedroom double precision, num_of_bed double precision, num_of_bath double precision, notes character varying)
    LANGUAGE plpgsql
    AS $$
begin
    return query 
    select a.building_id , a.apartment_id, a.apartment_floor,
			 a.apartment_name , a.area_total , a.area_bedroom,
             a.num_of_bed , a.num_of_bath , a.notes  from apartments a
    where (a.apartment_id, a.building_id) not in (select l.apartment_id, l.building_id from lease l where l.status = 'active');
end;
$$;


ALTER FUNCTION public.available_apartment() OWNER TO postgres;

--
-- Name: check_active_lease(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_active_lease() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT lease_id FROM lease 
                WHERE apartment_id = NEW.apartment_id
                AND building_id = NEW.building_id 
                AND status = 'active')
    THEN
    RAISE EXCEPTION 'apartment is already rented';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_active_lease() OWNER TO postgres;

--
-- Name: check_lease(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.check_lease()
    LANGUAGE plpgsql
    AS $$
declare
	each_record lease%ROWTYPE;
	cur_date date := CURRENT_DATE;
	end_date date;
	id_ int;
begin
	for each_record in select * from lease where status = 'active'
	loop
		id_ := each_record.lease_id;
		end_date := each_record.lease_end_date;
		
		if end_date < cur_date then
			update lease 
			set status = 'deactive'
			where lease_id = id_;
		end if;
	end loop;
end; $$;


ALTER PROCEDURE public.check_lease() OWNER TO postgres;

--
-- Name: confirm_payment(integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.confirm_payment(IN lease_payment_id_v integer, IN payment_type_v character varying)
    LANGUAGE plpgsql
    AS $$
begin 
	update lease_payments
	set payment_type = payment_type_v,
	status = 'paid',
	payment_date = CURRENT_DATE
	where lease_payment_id = lease_payment_id_v;
end;
$$;


ALTER PROCEDURE public.confirm_payment(IN lease_payment_id_v integer, IN payment_type_v character varying) OWNER TO postgres;

--
-- Name: count_tenants_use_service_between_dates(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.count_tenants_use_service_between_dates(_account_id integer, _from_date date, _to_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(DISTINCT tenant_id)
        FROM service_contracts AS sco
		JOIN service_categories AS sca USING (service_category_id)
		JOIN service_managers AS sm USING (service_id)
        WHERE (
			sco.end_date >= _from_date 
			AND _to_date >= sco.end_date
			AND sm.account_id = _account_id
		)
    );
END;
$$;


ALTER FUNCTION public.count_tenants_use_service_between_dates(_account_id integer, _from_date date, _to_date date) OWNER TO postgres;

--
-- Name: delete_occupant(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_occupant(IN _account_id integer, IN _occupant_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the occupant exists
    IF NOT EXISTS (SELECT 1 FROM occupants WHERE occupant_id = _occupant_id) THEN
        RAISE EXCEPTION 'Occupant % does not exist', _occupant_id;
    END IF;
    
	-- Check if tenant has permission to delete occupant 
    IF NOT EXISTS (
        SELECT 1 FROM accounts AS a
        JOIN tenants AS t ON a.account_id = t.account_id
        JOIN occupants AS o ON t.tenant_id = o.tenant_id
        WHERE a.account_id = _account_id AND o.occupant_id = _occupant_id
    ) THEN
        RAISE EXCEPTION 'Tenant does not have permission to delete occupant %', _occupant_id;
    END IF;
	
    -- Delete the occupant
    DELETE FROM occupants AS o
    WHERE o.occupant_id = _occupant_id;
END;
$$;


ALTER PROCEDURE public.delete_occupant(IN _account_id integer, IN _occupant_id integer) OWNER TO postgres;

--
-- Name: delete_service(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_service(service_id_v integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	account_id_v int;
BEGIN
	begin
		select account_id into account_id_v from service_managers where service_id = service_id_v;
		delete from accounts where account_id = account_id_v; -- delete account of service manager
		delete from services where service_id = service_id_v; -- delete service
	end;
end;
$$;


ALTER FUNCTION public.delete_service(service_id_v integer) OWNER TO postgres;

--
-- Name: delete_service_category(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_service_category(IN _account_id integer, IN _service_category_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the service contract exists and get the service_id
    IF NOT EXISTS (SELECT 1 FROM service_categories WHERE service_category_id = _service_category_id) THEN
        RAISE EXCEPTION 'Service category % does not exist', _service_category_id;
    END IF;

    -- Check if service_manager has permission to delete service
    IF NOT EXISTS (
        SELECT 1 FROM service_managers AS sm
        JOIN services AS s ON s.service_id = sm.service_id
        JOIN service_categories AS sc ON sc.service_id = s.service_id
        WHERE sm.account_id = _account_id AND sc.service_category_id = _service_category_id
    ) THEN
        RAISE EXCEPTION 'Service manager does not have permission to delete service category %', _service_category_id;
    END IF;

    -- Delete the service category
    DELETE FROM service_categories AS sc
    WHERE sc.service_category_id = _service_category_id;
END;
$$;


ALTER PROCEDURE public.delete_service_category(IN _account_id integer, IN _service_category_id integer) OWNER TO postgres;

--
-- Name: delete_service_contract(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_service_contract(IN _account_id integer, IN _service_contract_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the service contract exists and get the service_id
    IF NOT EXISTS (SELECT 1 FROM service_contracts WHERE service_contract_id = _service_contract_id) THEN
        RAISE EXCEPTION 'Service contract % does not exist', _service_contract_id;
    END IF;

    -- Check if service_manager has permission to delete service
    IF NOT EXISTS (
        SELECT 1 FROM accounts AS a
        JOIN service_managers AS sm ON a.account_id = sm.account_id
        JOIN services AS s ON s.service_id = sm.service_id
        JOIN service_categories AS sc ON sc.service_id = s.service_id
        JOIN service_contracts AS sc2 ON sc2.service_category_id = sc.service_category_id
        WHERE a.account_id = _account_id AND sc2.service_contract_id = _service_contract_id
    ) THEN
        RAISE EXCEPTION 'Service manager does not have permission to delete service contract %', _service_contract_id;
    END IF;

    -- Delete the service contract
    DELETE FROM service_contracts AS sco
    WHERE sco.service_contract_id = _service_contract_id;
END;
$$;


ALTER PROCEDURE public.delete_service_contract(IN _account_id integer, IN _service_contract_id integer) OWNER TO postgres;

--
-- Name: delete_tenant(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_tenant(tenant_id_v integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	account_id_v int;
BEGIN
	begin
		select account_id into account_id_v from tenants where tenant_id = tenant_id_v;
		delete from tenants where tenant_id = tenant_id_v; -- delete tenant record
		delete from accounts where account_id = account_id_v; -- delete account of that tenant
	end;
end;
$$;


ALTER FUNCTION public.delete_tenant(tenant_id_v integer) OWNER TO postgres;

--
-- Name: get_active_service_contracts_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_active_service_contracts_by_account_id(_account_id integer) RETURNS TABLE(service_contract_id integer, tenant_id integer, service_category_id integer, payment_date date, start_date date, end_date date, quantity integer, fee integer, status character varying, first_name character varying, last_name character varying, phone_number character varying, apartment_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
		SELECT sco.*, t.first_name, t.last_name, t.phone_number, l.apartment_id
		FROM service_contracts AS sco
		JOIN tenants AS t USING (tenant_id)
		JOIN lease AS l	USING (tenant_id)
		JOIN service_categories AS sca USING (service_category_id)
		JOIN services AS s USING (service_id)
		JOIN service_managers AS sm	USING (service_id)
		WHERE (sm.account_id = _account_id AND sco.status = 'active')
		ORDER BY sco.service_category_id, sco.service_contract_id;
END;
$$;


ALTER FUNCTION public.get_active_service_contracts_by_account_id(_account_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: apartments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.apartments (
    building_id integer NOT NULL,
    apartment_id integer NOT NULL,
    apartment_floor integer NOT NULL,
    apartment_name character varying(7) NOT NULL,
    area_total double precision,
    area_bedroom double precision,
    area_bathroom double precision,
    num_of_bed double precision,
    num_of_bath double precision,
    notes character varying(3000)
);


ALTER TABLE public.apartments OWNER TO postgres;

--
-- Name: get_apartments_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_apartments_by_account_id(_account_id integer) RETURNS SETOF public.apartments
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT a.*
        FROM apartments AS a
        JOIN lease AS l USING (apartment_id, building_id)
        JOIN tenants AS t USING (tenant_id)
        WHERE t.account_id = _account_id;
END;
$$;


ALTER FUNCTION public.get_apartments_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: buildings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buildings (
    building_id integer NOT NULL,
    building_name character varying(10) NOT NULL,
    building_address character varying(50) NOT NULL
);


ALTER TABLE public.buildings OWNER TO postgres;

--
-- Name: get_building_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_building_by_account_id(_account_id integer) RETURNS SETOF public.buildings
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT b.* 
		FROM buildings AS b
		JOIN apartments AS a USING (building_id)
		JOIN lease AS l	USING (apartment_id, building_id)
		JOIN tenants AS t USING (tenant_id)
		WHERE (t.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_building_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: get_expired_service_contracts_by_account_id_after_days(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_expired_service_contracts_by_account_id_after_days(_account_id integer, _day_after integer) RETURNS TABLE(service_contract_id integer, tenant_id integer, service_category_id integer, payment_date date, start_date date, end_date date, quantity integer, fee integer, status character varying, first_name character varying, last_name character varying, phone_number character varying, apartment_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
		SELECT sco.*, t.first_name, t.last_name, t.phone_number, l.apartment_id
		FROM service_contracts AS sco
		JOIN tenants AS t USING (tenant_id)
		JOIN lease AS l	USING (tenant_id)
		JOIN service_categories AS sca USING (service_category_id)
		JOIN services AS s USING (service_id)
		JOIN service_managers AS sm	USING (service_id)
		WHERE (sm.account_id = _account_id AND (sco.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + _day_after)))
		ORDER BY sco.service_category_id, sco.service_contract_id;
END;
$$;


ALTER FUNCTION public.get_expired_service_contracts_by_account_id_after_days(_account_id integer, _day_after integer) OWNER TO postgres;

--
-- Name: lease; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lease (
    lease_id integer NOT NULL,
    building_id integer NOT NULL,
    apartment_id integer NOT NULL,
    tenant_id integer NOT NULL,
    lease_date date DEFAULT CURRENT_DATE,
    lease_start_date date NOT NULL,
    lease_end_date date NOT NULL,
    monthly_rent integer,
    status character varying(10),
    CONSTRAINT lease_date_constraint CHECK ((lease_start_date < lease_end_date)),
    CONSTRAINT lease_status_check CHECK ((((status)::text = 'active'::text) OR ((status)::text = 'deactive'::text)))
);


ALTER TABLE public.lease OWNER TO postgres;

--
-- Name: get_lease_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_lease_by_account_id(_account_id integer) RETURNS SETOF public.lease
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT l.*
		FROM lease as l
		JOIN tenants AS t USING (tenant_id)
		WHERE (t.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_lease_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: lease_payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lease_payments (
    lease_payment_id integer NOT NULL,
    lease_id integer NOT NULL,
    payment_date date,
    payment_type character varying(10),
    start_date date NOT NULL,
    end_date date NOT NULL,
    amount integer,
    status character varying(10),
    CONSTRAINT lease_payments_status_check CHECK ((((status)::text = 'unpaid'::text) OR ((status)::text = 'paid'::text)))
);


ALTER TABLE public.lease_payments OWNER TO postgres;

--
-- Name: get_lease_payments_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_lease_payments_by_account_id(_account_id integer) RETURNS SETOF public.lease_payments
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT lp.*
		FROM lease_payments AS lp
		JOIN lease AS l	USING (lease_id)
		JOIN tenants AS t USING (tenant_id)
		WHERE (t.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_lease_payments_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: get_name(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_name(_account_id integer, _role_id integer) RETURNS TABLE(first_name character varying, last_name character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	_first_name VARCHAR;
	_last_name VARCHAR;
BEGIN 
	IF (_role_id = 1) THEN
		_first_name := 'Admin';
		_last_name := 'Account';
	
	ELSIF (_role_id = 2) THEN
		SELECT
			sm.first_name,
			sm.last_name
		INTO 
			_first_name,
			_last_name
		FROM service_managers AS sm
		JOIN accounts AS a USING (account_id)
		WHERE a.account_id = _account_id;
		
	ELSE
		SELECT
			t.first_name,
			t.last_name
		INTO 
			_first_name,
			_last_name
		FROM tenants AS t
		JOIN accounts AS a USING (account_id)
		WHERE a.account_id = _account_id;
	END IF;

	RETURN QUERY SELECT _first_name, _last_name;
END;
$$;


ALTER FUNCTION public.get_name(_account_id integer, _role_id integer) OWNER TO postgres;

--
-- Name: occupants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.occupants (
    occupant_id integer NOT NULL,
    tenant_id integer NOT NULL,
    last_name character varying(20) NOT NULL,
    first_name character varying(20) NOT NULL,
    id_card character varying(20) DEFAULT NULL::character varying,
    phone_number character varying(15) DEFAULT NULL::character varying
);


ALTER TABLE public.occupants OWNER TO postgres;

--
-- Name: get_occupants_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_occupants_by_account_id(_account_id integer) RETURNS SETOF public.occupants
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT o.* 
	FROM occupants AS o
	JOIN tenants AS t USING (tenant_id)
	WHERE (t.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_occupants_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: get_role_and_account_id(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_role_and_account_id(_username character varying, _password character varying) RETURNS TABLE(_role_id integer, _account_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY SELECT role_id, account_id 
                 FROM accounts 
                 WHERE username = _username
                 AND password_hash = _password;
END;
$$;


ALTER FUNCTION public.get_role_and_account_id(_username character varying, _password character varying) OWNER TO postgres;

--
-- Name: services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services (
    service_id integer NOT NULL,
    service_name character varying(20) NOT NULL,
    note text
);


ALTER TABLE public.services OWNER TO postgres;

--
-- Name: get_service_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_service_by_account_id(_account_id integer) RETURNS SETOF public.services
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
	    SELECT s.* 
		FROM services AS s
		JOIN service_managers AS sm USING (service_id)
		WHERE (sm.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_service_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: service_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_categories (
    service_id integer NOT NULL,
    service_category_id integer NOT NULL,
    service_category_name character varying(20) NOT NULL,
    price integer NOT NULL,
    note text
);


ALTER TABLE public.service_categories OWNER TO postgres;

--
-- Name: get_service_category_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_service_category_by_account_id(_account_id integer) RETURNS SETOF public.service_categories
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
	    SELECT sca.*
		FROM service_categories AS sca
		JOIN service_managers AS sm USING (service_id)
		WHERE (sm.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_service_category_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: get_service_contracts_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_service_contracts_by_account_id(_account_id integer) RETURNS TABLE(service_contract_id integer, tenant_id integer, service_category_id integer, payment_date date, start_date date, end_date date, quantity integer, fee integer, status character varying, first_name character varying, last_name character varying, phone_number character varying, apartment_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
		SELECT sco.*, t.first_name, t.last_name, t.phone_number, l.apartment_id
		FROM service_contracts AS sco
		JOIN tenants AS t USING (tenant_id)
		JOIN lease AS l USING (tenant_id)
		JOIN service_categories AS sca USING (service_category_id)
		JOIN services AS s ON sca.service_id = s.service_id
		WHERE EXISTS (
			SELECT 1
			FROM service_managers AS sm
			WHERE sm.service_id = s.service_id
				AND sm.account_id = _account_id
		)
		ORDER BY service_category_id, service_contract_id;
END;
$$;


ALTER FUNCTION public.get_service_contracts_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: get_service_contracts_by_account_id_and_tenant_id(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_service_contracts_by_account_id_and_tenant_id(_account_id integer, _tenant_id integer) RETURNS TABLE(service_contract_id integer, tenant_id integer, service_category_id integer, payment_date date, start_date date, end_date date, quantity integer, fee integer, status character varying, first_name character varying, last_name character varying, phone_number character varying, apartment_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
	SELECT sco.*,  t.first_name, t.last_name, t.phone_number, l.apartment_id
		FROM service_contracts AS sco
		JOIN tenants AS t USING (tenant_id)
		JOIN lease AS l	USING (tenant_id)
		JOIN service_categories AS sca USING (service_category_id)
		JOIN services AS s USING (service_id)
		JOIN service_managers AS sm	USING (service_id)
		WHERE (sm.account_id = _account_id AND t.tenant_id = _tenant_id)
		ORDER BY sco.service_category_id, sco.service_contract_id;
END;
$$;


ALTER FUNCTION public.get_service_contracts_by_account_id_and_tenant_id(_account_id integer, _tenant_id integer) OWNER TO postgres;

--
-- Name: service_managers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_managers (
    account_id integer,
    service_manager_id integer NOT NULL,
    service_id integer,
    last_name character varying(10) NOT NULL,
    first_name character varying(10) NOT NULL,
    email character varying(50) NOT NULL,
    phone_number character varying(15)
);


ALTER TABLE public.service_managers OWNER TO postgres;

--
-- Name: get_service_manager_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_service_manager_by_account_id(_account_id integer) RETURNS SETOF public.service_managers
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    	SELECT * 
		FROM service_managers AS sm
		WHERE (sm.account_id = _account_id);
END;
$$;


ALTER FUNCTION public.get_service_manager_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: tenants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tenants (
    tenant_id integer NOT NULL,
    account_id integer,
    last_name character varying(20) NOT NULL,
    first_name character varying(20) NOT NULL,
    id_card character varying(20) NOT NULL,
    email character varying(50) NOT NULL,
    phone_number character varying(15) NOT NULL
);


ALTER TABLE public.tenants OWNER TO postgres;

--
-- Name: get_tenants_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_tenants_by_account_id(_account_id integer) RETURNS SETOF public.tenants
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM tenants AS t
    WHERE t.account_id = _account_id;
END;
$$;


ALTER FUNCTION public.get_tenants_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: get_unpaid_lease_payments_by_account_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_unpaid_lease_payments_by_account_id(_account_id integer) RETURNS SETOF public.lease_payments
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT lp.*
		FROM lease_payments AS lp
		JOIN lease AS l USING (lease_id)
		JOIN tenants AS t USING (tenant_id)
		WHERE (t.account_id = _account_id AND lp.status = 'unpaid');
END;
$$;


ALTER FUNCTION public.get_unpaid_lease_payments_by_account_id(_account_id integer) OWNER TO postgres;

--
-- Name: insert_new_resident(character varying, character varying, character varying, character varying, character varying, date, date, integer, integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_new_resident(IN last_name character varying, IN first_name character varying, IN id_card character varying, IN email character varying, IN phone_number character varying, IN lease_start_date date, IN lease_end_date date, IN monthly_rent integer, IN apartment_id_v integer, IN building_id_v integer, IN username character varying)
    LANGUAGE plpgsql
    AS $$ 
	DECLARE 
	tenant_id_v INT;
	lease_id_v INT;
	account_id_v INT;
	end_date_v_final date := lease_end_date;
  	start_date_v date := LEASE_START_DATE;
	end_date_v date:= start_date_v + interval '1 month';
	amount_v int := monthly_rent;
	create_role_statement text := 'CREATE ROLE ' || username || ' LOGIN PASSWORD ''random_password_hash'' in role tenant_group;';
	BEGIN 
	-- IF (
	--         select l.lease_id
	--         from lease l
	--         where
	--             l.apartment_id = apartment_id_v
	--             AND l.building_id = building_id_v
	--             AND l.status = 'active'
	--     ) is not null then raise exception 'apartment is already rented';
	-- else
	BEGIN
	-- insert a tenant record
	INSERT INTO
	    "tenants" (
	        "last_name",
	        "first_name",
	        "id_card",
	        "email",
	        "phone_number"
	    )
	VALUES (
	        last_name,
	        first_name,
	        id_card,
	        email,
	        phone_number
	    )
	RETURNING
	    "tenant_id" INTO tenant_id_v;
	-- insert a lease record
	INSERT INTO
	    "lease" (
	        "apartment_id",
	        "building_id",
	        "tenant_id",
	        "lease_start_date",
	        "lease_end_date",
	        "monthly_rent",
	        "status"
	    )
	VALUES (
	        apartment_id_v,
	        building_id_v,
	        tenant_id_v,
	        lease_start_date,
	        lease_end_date,
	        monthly_rent,
	        'active'
	    )
	RETURNING
	    "lease_id" INTO lease_id_v;
		-- insert account record
	INSERT INTO
	    "accounts" (
	        "username",
	        "password_hash",
	        "role_id"
	    )
	VALUES (
	        username,
	        'random_password_hash',
	        3
	    ) -- TODO: generate a random password hash
	RETURNING
	    "account_id" INTO account_id_v;

	EXECUTE create_role_statement;
	-- assign account_id to tenant
	UPDATE "tenants"
	SET "account_id" = account_id_v
	WHERE "tenant_id" = tenant_id_v;
-- 	add lease_payment
-- 	end_date_v := start_date_v + interval '1 month';
	while end_date_v <= end_date_v_final loop
		insert into lease_payments(lease_id, start_date, end_date, amount, status) 
		values(lease_id_v, start_date_v, end_date_v, amount_v, 'unpaid');
		start_date_v := start_date_v + interval '1 month';
		end_date_v := end_date_v + interval '1 month';
	end loop;
	
	END;
	-- end if;
	END;
$$;


ALTER PROCEDURE public.insert_new_resident(IN last_name character varying, IN first_name character varying, IN id_card character varying, IN email character varying, IN phone_number character varying, IN lease_start_date date, IN lease_end_date date, IN monthly_rent integer, IN apartment_id_v integer, IN building_id_v integer, IN username character varying) OWNER TO postgres;

--
-- Name: insert_new_service(character varying, character varying, character varying, character varying, character varying, character varying, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_new_service(IN last_name_v character varying, IN first_name_v character varying, IN email_v character varying, IN phone_number_v character varying, IN username_v character varying, IN service_name_v character varying, IN note_v text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    service_id_v INT;
    service_manager_id_v INT;
    account_id_v INT;
    create_role_statement TEXT := 'CREATE ROLE ' || username_v || ' LOGIN PASSWORD ''random_password_hash'' in role manager_group;';
BEGIN
    IF (
        SELECT service_name
        FROM services s
        WHERE s.service_name = service_name_v
    ) IS NOT NULL THEN
        RAISE EXCEPTION 'Service has already been created';
    ELSE
        BEGIN
            -- insert service record
            INSERT INTO services(service_name, note)
            VALUES (service_name_v, note_v)
            RETURNING service_id INTO service_id_v;
            -- insert service manager record
            INSERT INTO service_managers(
                service_id,
                last_name,
                first_name,
                email,
                phone_number
            )
            VALUES (
                service_id_v,
                last_name_v,
                first_name_v,
                email_v,
                phone_number_v
            )
            RETURNING service_manager_id INTO service_manager_id_v;
            -- insert account record
            INSERT INTO "accounts" (
                "username",
                "password_hash",
                "role_id"
            )
            VALUES (
                username_v,
                'random_password_hash',
                2
            ) -- TODO: generate a random password hash
            RETURNING "account_id" INTO account_id_v;
            -- create role in DB
            EXECUTE create_role_statement;
            -- assign account_id to service manager
            UPDATE "service_managers"
            SET "account_id" = account_id_v
            WHERE "service_manager_id" = service_manager_id_v;
        END;
    END IF;
END;
$$;


ALTER PROCEDURE public.insert_new_service(IN last_name_v character varying, IN first_name_v character varying, IN email_v character varying, IN phone_number_v character varying, IN username_v character varying, IN service_name_v character varying, IN note_v text) OWNER TO postgres;

--
-- Name: insert_occupants(integer, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_occupants(IN _account_id integer, IN _last_name character varying, IN _first_name character varying, IN _id_card character varying, IN _phone_number character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE _tenant_id INT;
BEGIN
	-- Get tenant_id and store it into _tenant_id
    SELECT tenant_id INTO _tenant_id FROM tenants WHERE account_id = _account_id;

    IF _tenant_id IS NULL THEN
        RAISE EXCEPTION 'No tenant found for account_id: %', _account_id;
    END IF;

	IF _last_name = '' THEN
        RAISE EXCEPTION 'Must be input last name';
    END IF;

	IF _first_name = '' THEN
        RAISE EXCEPTION 'Must be input first name';
    END IF;
	
    INSERT INTO occupants
    VALUES (DEFAULT, _tenant_id, _last_name , _first_name , _id_card , _phone_number);
END;
$$;


ALTER PROCEDURE public.insert_occupants(IN _account_id integer, IN _last_name character varying, IN _first_name character varying, IN _id_card character varying, IN _phone_number character varying) OWNER TO postgres;

--
-- Name: insert_service_category(integer, integer, character varying, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_service_category(IN _account_id integer, IN _service_id integer, IN _service_category_name character varying, IN _price integer, IN _note character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the service exists
    IF NOT EXISTS (SELECT 1 FROM services WHERE service_id = _service_id) THEN
        RAISE EXCEPTION 'Service % does not exist', _service_id;
    END IF;

    -- Check if service manager has permission to the service
    IF NOT EXISTS (SELECT 1 FROM service_managers WHERE service_id = _service_id AND account_id = _account_id) THEN
        RAISE EXCEPTION 'Service Manager does not have permission to the service %', _service_id;
    END IF;
    -- Check if the service category name is valid
    IF _service_category_name NOT IN ('monthly', 'yearly') THEN
        RAISE EXCEPTION 'Service category name must be "monthly" or "yearly"';
    END IF;
    -- Check if the price is valid
    IF _price <= 0 THEN
        RAISE EXCEPTION 'Price must be larger than 0';
    END IF;
    -- Insert the new service category
    INSERT INTO service_categories
    VALUES (_service_id , DEFAULT , _service_category_name , _price , _note);
END;
$$;


ALTER PROCEDURE public.insert_service_category(IN _account_id integer, IN _service_id integer, IN _service_category_name character varying, IN _price integer, IN _note character varying) OWNER TO postgres;

--
-- Name: insert_service_contract(integer, integer, integer, date, date, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_service_contract(IN _account_id integer, IN _tenant_id integer, IN _service_category_id integer, IN _payment_date date, IN _end_date date, IN _quantity integer)
    LANGUAGE plpgsql
    AS $$
DECLARE _fee INT;
BEGIN
    -- Check if the tenant exists
    IF NOT EXISTS (SELECT 1 FROM tenants AS t WHERE t.tenant_id = _tenant_id) THEN
        RAISE EXCEPTION 'Tenant % does not exist', _tenant_id;
    END IF;
	-- Check if the service category exists
    IF NOT EXISTS (SELECT price FROM service_categories AS sca WHERE sca.service_category_id = _service_category_id) THEN
        RAISE EXCEPTION 'Service category % does not exist', _service_category_id;
    ELSE
		SELECT sca.price * _quantity INTO _fee FROM service_categories AS sca WHERE service_category_id = _service_category_id;
	END IF;

    -- Check if service_manager has permission for the service category
    IF NOT EXISTS (
        SELECT 1 FROM service_managers AS sm
        JOIN services AS s ON s.service_id = sm.service_id
        JOIN service_categories AS sc ON sc.service_id = s.service_id
        WHERE sm.account_id = _account_id AND sc.service_category_id = _service_category_id
    ) THEN
        RAISE EXCEPTION 'Service manager does not have permission to delete service category %', _service_category_id;
    END IF;

    -- Check if payment date is valid
    IF _payment_date > NOW() THEN
        RAISE EXCEPTION 'Payment date cannot be in the future';
    END IF;
    -- Check if end date is valid
    IF (_end_date < NOW() OR _end_date < _payment_date) THEN
        RAISE EXCEPTION 'End date cannot be in the past or lower than start date';
    END IF;
    -- Check if quantity and fee are valid
    IF _quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be larger than 0';
    END IF;
    IF _fee <= 0 OR _fee IS NULL THEN
        RAISE EXCEPTION 'Fee % must be larger than 0', _fee;
    END IF;
    -- Insert the new service contract
    INSERT INTO service_contracts
    VALUES (DEFAULT, _tenant_id , _service_category_id , _payment_date , NOW() , _end_date , _quantity ,  _fee , 'active');
END;
$$;


ALTER PROCEDURE public.insert_service_contract(IN _account_id integer, IN _tenant_id integer, IN _service_category_id integer, IN _payment_date date, IN _end_date date, IN _quantity integer) OWNER TO postgres;

--
-- Name: lease_expired_days(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lease_expired_days(days_v integer) RETURNS TABLE(lease_id integer, building_id integer, apartment_id integer, tenant_id integer, lease_end_date date, status character varying, remaining_days integer)
    LANGUAGE plpgsql
    AS $$ 
	BEGIN RETURN QUERY
	SELECT
	    l.lease_id,
	    l.building_id,
	    l.apartment_id,
	    l.tenant_id,
	    l.lease_end_date,
	    l.status, (
	        l.lease_end_date - CURRENT_DATE
	    ) as remaining_days
	FROM lease l
	WHERE
	    l.status = 'active'
	    AND l.lease_end_date - CURRENT_DATE <= days_v
	ORDER BY l.building_id;
	END;
	$$;


ALTER FUNCTION public.lease_expired_days(days_v integer) OWNER TO postgres;

--
-- Name: refresh_service_contract(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.refresh_service_contract()
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE service_contracts
	SET status = CASE
		WHEN end_date < NOW() OR start_date > NOW() THEN 'deactive'
		ELSE 'active'
	END;
END;
$$;


ALTER PROCEDURE public.refresh_service_contract() OWNER TO postgres;

--
-- Name: total_resident(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.total_resident() RETURNS TABLE(building_id integer, total bigint)
    LANGUAGE plpgsql
    AS $$BEGIN 
	RETURN QUERY
	SELECT l.building_id, (count(distinct o.occupant_id) + count(distinct l.tenant_id)) as total
	FROM occupants o JOIN lease l ON o.tenant_id = l.tenant_id
	WHERE l.status = 'active' 
	group by l.building_id;
	END;
	$$;


ALTER FUNCTION public.total_resident() OWNER TO postgres;

--
-- Name: total_service(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.total_service() RETURNS TABLE(service_id integer, service_name character varying, note text, service_manager_id integer, last_name character varying, first_name character varying, email character varying, phone_number character varying)
    LANGUAGE plpgsql
    AS $$ 
	BEGIN RETURN QUERY
	SELECT
	    s.service_id,
	    s.service_name,
	    s.note,
	    sm.service_manager_id,
	    sm.last_name,
	    sm.first_name,
	    sm.email,
	    sm.phone_number
	FROM services s
	    JOIN service_managers sm ON s.service_id = sm.service_id
	ORDER BY s.service_id;
	END;
	$$;


ALTER FUNCTION public.total_service() OWNER TO postgres;

--
-- Name: view_active_lease(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.view_active_lease() RETURNS TABLE(apartment_name character varying, lease_id integer, building_id integer, tenant_id integer, lease_date date, lease_start_date date, monthly_rent integer, status character varying)
    LANGUAGE plpgsql
    AS $$
begin
	return query 
	select a.apartment_name, l.lease_id,
			 l.building_id ,
			 l.tenant_id ,
			 l.lease_date ,
			 l.lease_start_date,
			 l.monthly_rent ,
			 l.status from lease l join apartments a on l.apartment_id = a.apartment_id
	where l.status = 'active' 
	order by l.building_id ASC,a.apartment_name ASC;
end;
$$;


ALTER FUNCTION public.view_active_lease() OWNER TO postgres;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts (
    username character varying(20) NOT NULL,
    password_hash character varying(50) NOT NULL,
    account_id integer NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accounts_account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.accounts_account_id_seq OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_account_id_seq OWNED BY public.accounts.account_id;


--
-- Name: lease_lease_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lease_lease_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lease_lease_id_seq OWNER TO postgres;

--
-- Name: lease_lease_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lease_lease_id_seq OWNED BY public.lease.lease_id;


--
-- Name: lease_payments_lease_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lease_payments_lease_payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lease_payments_lease_payment_id_seq OWNER TO postgres;

--
-- Name: lease_payments_lease_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lease_payments_lease_payment_id_seq OWNED BY public.lease_payments.lease_payment_id;


--
-- Name: occupants_occupant_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.occupants_occupant_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.occupants_occupant_id_seq OWNER TO postgres;

--
-- Name: occupants_occupant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.occupants_occupant_id_seq OWNED BY public.occupants.occupant_id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    role_id integer NOT NULL,
    role_name character varying(20) NOT NULL
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: service_categories_service_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_categories_service_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_categories_service_category_id_seq OWNER TO postgres;

--
-- Name: service_categories_service_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_categories_service_category_id_seq OWNED BY public.service_categories.service_category_id;


--
-- Name: service_contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_contracts (
    service_contract_id integer NOT NULL,
    tenant_id integer NOT NULL,
    service_category_id integer NOT NULL,
    payment_date date DEFAULT CURRENT_DATE,
    start_date date NOT NULL,
    end_date date NOT NULL,
    quantity integer NOT NULL,
    fee integer,
    status character varying(20),
    CONSTRAINT sc_date_constraint CHECK ((start_date < end_date)),
    CONSTRAINT service_contracts_status_check CHECK ((((status)::text = 'active'::text) OR ((status)::text = 'deactive'::text)))
);


ALTER TABLE public.service_contracts OWNER TO postgres;

--
-- Name: service_contracts_service_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_contracts_service_contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_contracts_service_contract_id_seq OWNER TO postgres;

--
-- Name: service_contracts_service_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_contracts_service_contract_id_seq OWNED BY public.service_contracts.service_contract_id;


--
-- Name: service_managers_service_manager_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_managers_service_manager_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_managers_service_manager_id_seq OWNER TO postgres;

--
-- Name: service_managers_service_manager_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_managers_service_manager_id_seq OWNED BY public.service_managers.service_manager_id;


--
-- Name: services_service_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.services_service_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.services_service_id_seq OWNER TO postgres;

--
-- Name: services_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_service_id_seq OWNED BY public.services.service_id;


--
-- Name: tenants_tenant_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tenants_tenant_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tenants_tenant_id_seq OWNER TO postgres;

--
-- Name: tenants_tenant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tenants_tenant_id_seq OWNED BY public.tenants.tenant_id;


--
-- Name: accounts account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN account_id SET DEFAULT nextval('public.accounts_account_id_seq'::regclass);


--
-- Name: lease lease_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease ALTER COLUMN lease_id SET DEFAULT nextval('public.lease_lease_id_seq'::regclass);


--
-- Name: lease_payments lease_payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease_payments ALTER COLUMN lease_payment_id SET DEFAULT nextval('public.lease_payments_lease_payment_id_seq'::regclass);


--
-- Name: occupants occupant_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.occupants ALTER COLUMN occupant_id SET DEFAULT nextval('public.occupants_occupant_id_seq'::regclass);


--
-- Name: service_categories service_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_categories ALTER COLUMN service_category_id SET DEFAULT nextval('public.service_categories_service_category_id_seq'::regclass);


--
-- Name: service_contracts service_contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_contracts ALTER COLUMN service_contract_id SET DEFAULT nextval('public.service_contracts_service_contract_id_seq'::regclass);


--
-- Name: service_managers service_manager_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers ALTER COLUMN service_manager_id SET DEFAULT nextval('public.service_managers_service_manager_id_seq'::regclass);


--
-- Name: services service_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN service_id SET DEFAULT nextval('public.services_service_id_seq'::regclass);


--
-- Name: tenants tenant_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants ALTER COLUMN tenant_id SET DEFAULT nextval('public.tenants_tenant_id_seq'::regclass);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (username, password_hash, account_id, role_id) FROM stdin;
admin1	admin123	4	1
dtdng2	random_password_hash	5	3
cferran2	random_password_hash	7	3
esouch3	random_password_hash	8	3
cbowart4	random_password_hash	9	3
klabatie5	random_password_hash	10	3
astaniford6	random_password_hash	11	3
chambleton7	random_password_hash	12	3
gmackniely8	random_password_hash	13	3
odondon9	random_password_hash	14	3
pkenworthya	random_password_hash	15	3
hellswortheb	random_password_hash	16	3
etreffryc	random_password_hash	17	3
ilegerd	random_password_hash	18	3
kgilliese	random_password_hash	19	3
lfelcef	random_password_hash	20	3
mbarthropg	random_password_hash	21	3
lbattyeh	random_password_hash	22	3
ptappori	random_password_hash	23	3
mgoundryj	random_password_hash	24	3
rtwelvetreesk	random_password_hash	25	3
hcolleltonl	random_password_hash	26	3
kjennerm	random_password_hash	27	3
jfennan	random_password_hash	28	3
imorao	random_password_hash	29	3
sbluckp	random_password_hash	30	3
jmacwilliamq	random_password_hash	31	3
wfavillr	random_password_hash	32	3
aughellis	random_password_hash	33	3
rrennoldst	random_password_hash	34	3
lhoferu	random_password_hash	35	3
bgibbesonv	random_password_hash	36	3
sfawdryw	random_password_hash	37	3
cpidonx	random_password_hash	38	3
flayney	random_password_hash	39	3
yshoobridgez	random_password_hash	40	3
obuterton10	random_password_hash	41	3
ghales11	random_password_hash	42	3
lwaterhouse12	random_password_hash	43	3
eboodell13	random_password_hash	44	3
echidgey14	random_password_hash	45	3
rcheesworth15	random_password_hash	46	3
mpottie16	random_password_hash	47	3
pgerin17	random_password_hash	48	3
agascoigne18	random_password_hash	49	3
rsaltman19	random_password_hash	50	3
mathy1a	random_password_hash	51	3
agarvill1b	random_password_hash	52	3
lmarchand1c	random_password_hash	53	3
balibone1d	random_password_hash	54	3
smurrhardt1e	random_password_hash	55	3
lcapitano1f	random_password_hash	56	3
ciddenden1g	random_password_hash	57	3
tpraton1h	random_password_hash	58	3
bpaliser1i	random_password_hash	59	3
dbellon1j	random_password_hash	60	3
clinnell1k	random_password_hash	61	3
lklinck1l	random_password_hash	62	3
jpowderham1m	random_password_hash	63	3
dproughten1n	random_password_hash	64	3
tdarmody1o	random_password_hash	65	3
chabbin1p	random_password_hash	66	3
cwingar1q	random_password_hash	67	3
gdollman1r	random_password_hash	68	3
emoxham1s	random_password_hash	69	3
nrobertsson1t	random_password_hash	70	3
brodgerson1u	random_password_hash	71	3
skringe1v	random_password_hash	72	3
bfinnis1w	random_password_hash	73	3
rgrunnill1x	random_password_hash	74	3
cmccloughen1y	random_password_hash	75	3
jstrickland1z	random_password_hash	76	3
kfurness20	random_password_hash	77	3
krevely21	random_password_hash	78	3
fhynard22	random_password_hash	79	3
arowat23	random_password_hash	80	3
kstiggles24	random_password_hash	81	3
ehannah25	random_password_hash	82	3
lmapples26	random_password_hash	83	3
sranklin27	random_password_hash	84	3
hstelli28	random_password_hash	85	3
shargie29	random_password_hash	86	3
mkitteman2a	random_password_hash	87	3
ncancellor2b	random_password_hash	88	3
mcrew2c	random_password_hash	89	3
cmedlin2d	random_password_hash	90	3
acunio2e	random_password_hash	91	3
mbealing2f	random_password_hash	92	3
jcorday2g	random_password_hash	93	3
basling2h	random_password_hash	94	3
kodeson2i	random_password_hash	95	3
jreinhard2j	random_password_hash	96	3
dparrington2k	random_password_hash	97	3
tswindall2l	random_password_hash	98	3
gjacomb2m	random_password_hash	99	3
jheadford2n	random_password_hash	100	3
lborne2o	random_password_hash	101	3
mshields2p	random_password_hash	102	3
cjenicke2q	random_password_hash	103	3
abutterick2r	random_password_hash	104	3
manager1	manager1123	1	2
manager2	manager2123	2	2
manager3	manager3123	3	2
tenant1	tenant1123	6	3
\.


--
-- Data for Name: apartments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.apartments (building_id, apartment_id, apartment_floor, apartment_name, area_total, area_bedroom, area_bathroom, num_of_bed, num_of_bath, notes) FROM stdin;
1	1	1	111	132	3	2	3	2	magna
1	2	2	122	118	3	1	2	2	donec ut dolor morbi
1	3	3	133	116	3	2	3	1	turpis integer aliquet massa
1	4	4	144	140	2	1	1	2	vulputate elementum nullam varius nulla
1	5	5	155	100	2	2	4	1	ut
1	6	6	166	128	1	2	4	1	praesent lectus vestibulum quam
1	7	7	177	134	3	2	1	2	etiam pretium
1	8	8	188	116	2	2	1	2	in
1	9	9	199	135	3	2	2	2	consequat in consequat ut nulla
1	10	10	11010	109	3	1	3	1	ipsum ac tellus semper interdum
1	11	1	1111	116	1	2	4	1	nisi venenatis tristique fusce
1	12	2	1212	129	1	2	3	2	tellus in sagittis dui
1	13	3	1313	121	1	1	2	2	convallis morbi odio
1	14	4	1414	131	3	2	3	1	adipiscing elit proin interdum
1	15	5	1515	134	3	2	1	1	congue vivamus metus
1	16	6	1616	109	1	2	2	1	amet sapien dignissim vestibulum vestibulum
1	17	7	1717	128	2	2	3	1	nam congue risus semper
1	18	8	1818	130	2	2	3	1	blandit non interdum in ante
1	19	9	1919	132	1	1	1	1	porta volutpat erat quisque
1	20	10	11020	125	3	1	3	2	adipiscing lorem vitae mattis nibh
1	21	1	1121	129	3	2	2	2	pharetra magna
1	22	2	1222	114	3	1	3	2	proin leo odio porttitor
1	23	3	1323	100	1	1	1	2	placerat praesent blandit
1	24	4	1424	102	1	2	2	2	vulputate
1	25	5	1525	140	1	2	3	1	odio curabitur
1	26	6	1626	128	3	2	1	1	velit id
1	27	7	1727	128	2	1	3	1	aliquam convallis nunc proin at
1	28	8	1828	122	1	1	3	1	erat nulla
1	29	9	1929	103	1	2	3	2	primis in faucibus orci luctus
1	30	10	11030	116	3	2	3	2	blandit
1	31	1	1131	150	1	2	1	1	iaculis congue vivamus metus arcu
1	32	2	1232	146	2	2	4	2	habitasse platea dictumst aliquam augue
1	33	3	1333	105	2	1	3	2	elementum ligula vehicula consequat
1	34	4	1434	126	1	1	3	2	morbi quis
1	35	5	1535	127	1	2	3	2	dapibus augue vel accumsan tellus
1	36	6	1636	123	2	1	4	1	in purus eu magna vulputate
1	37	7	1737	117	1	2	4	2	tempus vivamus
1	38	8	1838	106	2	1	3	1	elementum
1	39	9	1939	117	2	2	2	2	ultrices enim lorem
1	40	10	11040	101	1	1	3	2	in
1	41	1	1141	114	2	2	4	2	ut
1	42	2	1242	141	3	1	4	1	enim
1	43	3	1343	124	1	2	2	1	eget nunc donec
1	44	4	1444	146	1	1	1	2	metus sapien ut nunc vestibulum
1	45	5	1545	139	1	2	4	2	nunc nisl duis bibendum felis
1	46	6	1646	122	1	1	4	1	leo
1	47	7	1747	134	1	2	2	1	sit amet consectetuer adipiscing
1	48	8	1848	119	2	1	2	2	mauris ullamcorper
1	49	9	1949	150	2	1	1	2	est risus
1	50	10	11050	107	3	2	3	1	adipiscing elit proin interdum mauris
2	1	1	211	143	1	2	3	1	lacus
2	2	2	222	140	3	1	3	2	ante ipsum
2	3	3	233	149	2	1	4	1	primis in
2	4	4	244	133	1	1	1	1	ut volutpat
2	5	5	255	145	2	2	2	2	sociis
2	6	6	266	100	1	2	2	1	luctus
2	7	7	277	135	1	2	1	1	iaculis diam erat
2	8	8	288	128	3	2	4	1	porttitor
2	9	9	299	142	2	2	1	1	pede malesuada in imperdiet
2	10	10	21010	131	1	1	4	1	eget massa
2	11	1	2111	105	2	1	1	1	non velit
2	12	2	2212	104	3	2	2	2	velit vivamus vel nulla eget
2	13	3	2313	128	1	2	4	2	quam pede lobortis ligula sit
2	14	4	2414	117	1	2	2	2	morbi vestibulum velit id pretium
2	15	5	2515	146	1	2	3	2	neque libero
2	16	6	2616	148	1	1	1	2	egestas
2	17	7	2717	118	2	2	3	1	amet
2	18	8	2818	100	1	2	3	2	nisi
2	19	9	2919	115	2	2	1	2	mi in porttitor
2	20	10	21020	133	3	1	4	1	augue
2	21	1	2121	142	1	2	4	1	id justo sit amet sapien
2	22	2	2222	107	2	2	1	2	nisi eu orci mauris lacinia
2	23	3	2323	133	1	1	3	1	non mauris morbi
2	24	4	2424	115	2	2	4	2	hendrerit
2	25	5	2525	138	1	1	4	1	curabitur at
2	26	6	2626	143	2	1	4	1	primis in
2	27	7	2727	116	3	1	3	2	in purus eu magna
2	28	8	2828	131	3	1	3	2	in
2	29	9	2929	132	3	2	1	1	posuere metus
2	30	10	21030	121	3	1	3	1	morbi odio odio
2	31	1	2131	141	3	1	2	2	eget rutrum at
2	32	2	2232	133	1	2	4	1	turpis adipiscing lorem vitae
2	33	3	2333	150	2	1	2	1	sed interdum venenatis turpis
2	34	4	2434	103	1	1	3	1	curabitur
2	35	5	2535	146	3	1	4	2	volutpat quam pede lobortis
2	36	6	2636	114	2	1	3	2	eu sapien
2	37	7	2737	125	1	1	2	2	interdum mauris ullamcorper purus sit
2	38	8	2838	118	3	1	2	1	porttitor
2	39	9	2939	145	3	2	2	1	odio in hac
2	40	10	21040	107	3	2	2	2	eget rutrum at lorem
2	41	1	2141	138	3	2	4	1	pharetra magna ac consequat metus
2	42	2	2242	150	1	1	3	2	ultrices posuere cubilia
2	43	3	2343	124	2	2	3	2	nam dui proin leo odio
2	44	4	2444	125	1	1	3	2	semper porta volutpat quam pede
2	45	5	2545	138	3	2	4	1	tempor
2	46	6	2646	131	3	1	1	1	morbi
2	47	7	2747	123	3	1	1	1	nulla nisl
2	48	8	2848	122	2	1	1	1	platea dictumst
2	49	9	2949	147	2	1	2	2	mi
2	50	10	21050	144	1	1	2	2	diam cras pellentesque volutpat dui
\.


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buildings (building_id, building_name, building_address) FROM stdin;
1	MM77	38 Haas Crossing
2	YN20	1134 Village Green Trail
\.


--
-- Data for Name: lease; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lease (lease_id, building_id, apartment_id, tenant_id, lease_date, lease_start_date, lease_end_date, monthly_rent, status) FROM stdin;
1	1	1	2	2023-02-20	2021-04-24	2023-04-24	4300000	active
2	1	3	3	2023-02-20	2022-12-21	2025-12-21	1300000	active
3	1	4	4	2023-02-20	2018-03-15	2023-03-15	9600000	active
4	1	5	5	2023-02-20	2022-06-12	2023-06-12	700000	active
5	1	6	6	2023-02-20	2022-10-11	2026-10-11	3300000	active
6	1	7	7	2023-02-20	2020-05-17	2025-05-17	5800000	active
7	1	10	10	2023-02-20	2022-12-27	2024-12-27	4300000	active
8	1	11	11	2023-02-20	2020-09-24	2024-09-24	8300000	active
9	1	12	12	2023-02-20	2022-09-22	2024-09-22	7700000	active
10	1	13	13	2023-02-20	2019-12-30	2023-12-30	3400000	active
11	1	14	14	2023-02-20	2019-11-02	2024-11-02	1100000	active
12	1	15	15	2023-02-20	2019-04-15	2024-04-15	1200000	active
13	1	16	16	2023-02-20	2022-08-04	2027-08-04	7500000	active
14	1	17	17	2023-02-20	2019-08-11	2023-08-11	9200000	active
15	1	18	18	2023-02-20	2021-02-19	2025-02-19	7400000	active
16	1	20	20	2023-02-20	2022-08-17	2027-08-17	6600000	active
17	1	23	23	2023-02-20	2021-12-16	2025-12-16	3700000	active
18	1	25	25	2023-02-20	2021-03-26	2025-03-26	800000	active
19	1	26	26	2023-02-20	2021-12-31	2025-12-31	1400000	active
20	1	27	27	2023-02-20	2020-12-12	2023-12-12	2200000	active
21	1	29	29	2023-02-20	2022-12-12	2025-12-12	1900000	active
22	1	35	35	2023-02-20	2020-11-27	2025-11-27	1400000	active
23	1	36	36	2023-02-20	2022-09-30	2027-09-30	9800000	active
24	1	37	37	2023-02-20	2022-11-13	2026-11-13	5200000	active
25	1	38	38	2023-02-20	2022-07-07	2025-07-07	3600000	active
26	1	39	39	2023-02-20	2022-04-11	2027-04-11	9700000	active
27	1	42	42	2023-02-20	2022-04-06	2023-04-06	6500000	active
28	1	43	43	2023-02-20	2021-07-13	2025-07-13	1400000	active
29	1	44	44	2023-02-20	2019-03-05	2024-03-05	3200000	active
30	1	45	45	2023-02-20	2020-02-19	2025-02-19	7300000	active
31	1	46	46	2023-02-20	2019-12-14	2024-12-14	8000000	active
32	1	47	47	2023-02-20	2019-12-15	2023-12-15	4200000	active
33	1	49	49	2023-02-20	2021-12-16	2025-12-16	6600000	active
34	2	3	53	2023-02-20	2022-05-04	2027-05-04	5300000	active
35	2	4	54	2023-02-20	2022-04-19	2024-04-19	1400000	active
36	2	5	55	2023-02-20	2020-05-12	2025-05-12	7500000	active
37	2	6	56	2023-02-20	2021-01-29	2024-01-29	3500000	active
38	2	7	57	2023-02-20	2021-08-18	2025-08-18	1400000	active
39	2	8	58	2023-02-20	2020-05-18	2024-05-18	9600000	active
40	2	11	61	2023-02-20	2020-03-04	2024-03-04	7900000	active
41	2	12	62	2023-02-20	2020-01-23	2025-01-23	4800000	active
42	2	15	65	2023-02-20	2023-02-14	2024-02-14	9700000	active
43	2	20	70	2023-02-20	2022-02-09	2027-02-09	2600000	active
44	2	21	71	2023-02-20	2021-06-07	2023-06-07	100000	active
45	2	22	72	2023-02-20	2020-12-28	2025-12-28	8900000	active
46	2	25	75	2023-02-20	2021-08-11	2026-08-11	9100000	active
47	2	28	78	2023-02-20	2018-07-20	2023-07-20	8200000	active
48	2	29	79	2023-02-20	2022-04-10	2027-04-10	6900000	active
49	2	32	82	2023-02-20	2022-11-26	2023-11-26	7900000	active
50	2	34	84	2023-02-20	2022-09-07	2026-09-07	2400000	active
51	2	35	85	2023-02-20	2021-06-28	2026-06-28	2900000	active
52	2	36	86	2023-02-20	2018-07-07	2023-07-07	7000000	active
53	2	37	87	2023-02-20	2022-05-07	2024-05-07	400000	active
54	2	42	92	2023-02-20	2022-09-14	2023-09-14	1800000	active
55	2	45	95	2023-02-20	2021-05-13	2026-05-13	700000	active
56	2	46	96	2023-02-20	2022-12-31	2026-12-31	8700000	active
57	2	48	98	2023-02-20	2019-05-08	2023-05-08	4500000	active
58	2	50	100	2023-02-20	2022-10-04	2027-10-04	2800000	active
59	1	8	8	2023-02-20	2019-09-07	2022-09-07	3600000	deactive
60	1	9	9	2023-02-20	2020-06-06	2021-06-06	1000000	deactive
61	1	19	19	2023-02-20	2018-05-15	2020-05-15	5200000	deactive
62	1	21	21	2023-02-20	2019-12-19	2020-12-19	1100000	deactive
63	1	22	22	2023-02-20	2019-02-17	2020-02-17	4300000	deactive
64	1	24	24	2023-02-20	2018-08-08	2022-08-08	1400000	deactive
65	1	28	28	2023-02-20	2018-07-09	2021-07-09	3300000	deactive
66	1	30	30	2023-02-20	2020-02-11	2021-02-11	4600000	deactive
67	1	31	31	2023-02-20	2018-06-29	2019-06-29	3300000	deactive
68	1	32	32	2023-02-20	2021-11-14	2022-11-14	7400000	deactive
69	1	33	33	2023-02-20	2022-02-16	2023-02-16	2700000	deactive
70	1	34	34	2023-02-20	2020-08-13	2022-08-13	6100000	deactive
71	1	40	40	2023-02-20	2018-10-23	2021-10-23	7200000	deactive
72	1	41	41	2023-02-20	2018-05-08	2020-05-08	3500000	deactive
73	1	48	48	2023-02-20	2019-01-15	2021-01-15	5400000	deactive
74	1	50	50	2023-02-20	2019-01-24	2021-01-24	4800000	deactive
75	2	1	51	2023-02-20	2018-06-02	2022-06-02	8400000	deactive
76	2	2	52	2023-02-20	2020-06-23	2021-06-23	5800000	deactive
77	2	9	59	2023-02-20	2018-06-09	2021-06-09	2000000	deactive
78	2	10	60	2023-02-20	2020-01-09	2021-01-09	9500000	deactive
79	2	13	63	2023-02-20	2018-08-27	2022-08-27	6500000	deactive
80	2	14	64	2023-02-20	2018-11-19	2019-11-19	5400000	deactive
81	2	16	66	2023-02-20	2020-03-11	2022-03-11	8500000	deactive
82	2	17	67	2023-02-20	2018-04-17	2019-04-17	2800000	deactive
83	2	18	68	2023-02-20	2018-12-19	2019-12-19	3500000	deactive
84	2	19	69	2023-02-20	2020-12-31	2021-12-31	200000	deactive
85	2	23	73	2023-02-20	2018-11-28	2019-11-28	9400000	deactive
86	2	24	74	2023-02-20	2018-05-30	2020-05-30	1900000	deactive
87	2	26	76	2023-02-20	2019-12-09	2020-12-09	6300000	deactive
88	2	27	77	2023-02-20	2020-09-30	2021-09-30	1700000	deactive
89	2	30	80	2023-02-20	2018-10-19	2020-10-19	9300000	deactive
90	2	31	81	2023-02-20	2019-04-10	2022-04-10	4500000	deactive
91	2	33	83	2023-02-20	2019-10-29	2020-10-29	1400000	deactive
92	2	38	88	2023-02-20	2021-05-16	2022-05-16	3000000	deactive
93	2	39	89	2023-02-20	2020-03-05	2021-03-05	7500000	deactive
94	2	40	90	2023-02-20	2019-01-22	2021-01-22	6600000	deactive
95	2	41	91	2023-02-20	2019-10-08	2020-10-08	8100000	deactive
96	2	43	93	2023-02-20	2019-01-17	2022-01-17	5200000	deactive
97	2	44	94	2023-02-20	2018-04-28	2020-04-28	5800000	deactive
98	2	47	97	2023-02-20	2019-06-18	2022-06-18	3500000	deactive
99	2	49	99	2023-02-20	2018-03-16	2020-03-16	8500000	deactive
\.


--
-- Data for Name: lease_payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lease_payments (lease_payment_id, lease_id, payment_date, payment_type, start_date, end_date, amount, status) FROM stdin;
3	1	\N	\N	2023-02-28	2023-03-28	1500	unpaid
4	1	\N	\N	2023-03-28	2023-04-28	1500	unpaid
5	1	\N	\N	2023-04-28	2023-05-28	1500	unpaid
6	1	\N	\N	2023-05-28	2023-06-28	1500	unpaid
7	1	\N	\N	2023-06-28	2023-07-28	1500	unpaid
8	1	\N	\N	2023-07-28	2023-08-28	1500	unpaid
9	1	\N	\N	2023-08-28	2023-09-28	1500	unpaid
10	1	\N	\N	2023-09-28	2023-10-28	1500	unpaid
11	1	\N	\N	2023-10-28	2023-11-28	1500	unpaid
12	1	\N	\N	2023-11-28	2023-12-28	1500	unpaid
13	1	\N	\N	2023-12-28	2024-01-28	1500	unpaid
14	1	\N	\N	2024-01-28	2024-02-28	1500	unpaid
15	1	\N	\N	2024-02-28	2024-03-28	1500	unpaid
16	1	\N	\N	2024-03-28	2024-04-28	1500	unpaid
17	1	\N	\N	2024-04-28	2024-05-28	1500	unpaid
18	1	\N	\N	2024-05-28	2024-06-28	1500	unpaid
19	1	\N	\N	2024-06-28	2024-07-28	1500	unpaid
20	1	\N	\N	2024-07-28	2024-08-28	1500	unpaid
21	1	\N	\N	2024-08-28	2024-09-28	1500	unpaid
22	1	\N	\N	2024-09-28	2024-10-28	1500	unpaid
23	1	\N	\N	2024-10-28	2024-11-28	1500	unpaid
24	1	\N	\N	2024-11-28	2024-12-28	1500	unpaid
25	1	\N	\N	2024-12-28	2025-01-28	1500	unpaid
26	1	\N	\N	2025-01-28	2025-02-28	1500	unpaid
27	1	\N	\N	2025-02-28	2025-03-28	1500	unpaid
28	1	\N	\N	2025-03-28	2025-04-28	1500	unpaid
29	1	\N	\N	2025-04-28	2025-05-28	1500	unpaid
30	1	\N	\N	2025-05-28	2025-06-28	1500	unpaid
31	1	\N	\N	2025-06-28	2025-07-28	1500	unpaid
32	1	\N	\N	2025-07-28	2025-08-28	1500	unpaid
33	1	\N	\N	2025-08-28	2025-09-28	1500	unpaid
34	1	\N	\N	2025-09-28	2025-10-28	1500	unpaid
35	1	\N	\N	2025-10-28	2025-11-28	1500	unpaid
36	1	\N	\N	2025-11-28	2025-12-28	1500	unpaid
59	2	\N	\N	2023-02-24	2023-03-24	4300000	unpaid
60	2	\N	\N	2023-03-24	2023-04-24	4300000	unpaid
63	3	\N	\N	2023-02-21	2023-03-21	1300000	unpaid
64	3	\N	\N	2023-03-21	2023-04-21	1300000	unpaid
65	3	\N	\N	2023-04-21	2023-05-21	1300000	unpaid
66	3	\N	\N	2023-05-21	2023-06-21	1300000	unpaid
67	3	\N	\N	2023-06-21	2023-07-21	1300000	unpaid
68	3	\N	\N	2023-07-21	2023-08-21	1300000	unpaid
69	3	\N	\N	2023-08-21	2023-09-21	1300000	unpaid
70	3	\N	\N	2023-09-21	2023-10-21	1300000	unpaid
71	3	\N	\N	2023-10-21	2023-11-21	1300000	unpaid
72	3	\N	\N	2023-11-21	2023-12-21	1300000	unpaid
73	3	\N	\N	2023-12-21	2024-01-21	1300000	unpaid
74	3	\N	\N	2024-01-21	2024-02-21	1300000	unpaid
75	3	\N	\N	2024-02-21	2024-03-21	1300000	unpaid
76	3	\N	\N	2024-03-21	2024-04-21	1300000	unpaid
77	3	\N	\N	2024-04-21	2024-05-21	1300000	unpaid
78	3	\N	\N	2024-05-21	2024-06-21	1300000	unpaid
79	3	\N	\N	2024-06-21	2024-07-21	1300000	unpaid
80	3	\N	\N	2024-07-21	2024-08-21	1300000	unpaid
81	3	\N	\N	2024-08-21	2024-09-21	1300000	unpaid
82	3	\N	\N	2024-09-21	2024-10-21	1300000	unpaid
83	3	\N	\N	2024-10-21	2024-11-21	1300000	unpaid
84	3	\N	\N	2024-11-21	2024-12-21	1300000	unpaid
85	3	\N	\N	2024-12-21	2025-01-21	1300000	unpaid
86	3	\N	\N	2025-01-21	2025-02-21	1300000	unpaid
87	3	\N	\N	2025-02-21	2025-03-21	1300000	unpaid
88	3	\N	\N	2025-03-21	2025-04-21	1300000	unpaid
89	3	\N	\N	2025-04-21	2025-05-21	1300000	unpaid
90	3	\N	\N	2025-05-21	2025-06-21	1300000	unpaid
91	3	\N	\N	2025-06-21	2025-07-21	1300000	unpaid
92	3	\N	\N	2025-07-21	2025-08-21	1300000	unpaid
93	3	\N	\N	2025-08-21	2025-09-21	1300000	unpaid
94	3	\N	\N	2025-09-21	2025-10-21	1300000	unpaid
95	3	\N	\N	2025-10-21	2025-11-21	1300000	unpaid
96	3	\N	\N	2025-11-21	2025-12-21	1300000	unpaid
1	1	2022-12-21	cash	2022-12-28	2023-01-28	1500	paid
2	1	2023-01-21	cash	2023-01-28	2023-02-28	1500	paid
57	2	2022-12-17	cash	2022-12-24	2023-01-24	4300000	paid
58	2	2023-01-17	cash	2023-01-24	2023-02-24	4300000	paid
61	3	2022-12-14	cash	2022-12-21	2023-01-21	1300000	paid
156	4	\N	\N	2023-02-15	2023-03-15	9600000	unpaid
165	5	\N	\N	2023-02-12	2023-03-12	700000	unpaid
166	5	\N	\N	2023-03-12	2023-04-12	700000	unpaid
167	5	\N	\N	2023-04-12	2023-05-12	700000	unpaid
168	5	\N	\N	2023-05-12	2023-06-12	700000	unpaid
173	6	\N	\N	2023-02-11	2023-03-11	3300000	unpaid
174	6	\N	\N	2023-03-11	2023-04-11	3300000	unpaid
175	6	\N	\N	2023-04-11	2023-05-11	3300000	unpaid
176	6	\N	\N	2023-05-11	2023-06-11	3300000	unpaid
177	6	\N	\N	2023-06-11	2023-07-11	3300000	unpaid
178	6	\N	\N	2023-07-11	2023-08-11	3300000	unpaid
179	6	\N	\N	2023-08-11	2023-09-11	3300000	unpaid
180	6	\N	\N	2023-09-11	2023-10-11	3300000	unpaid
181	6	\N	\N	2023-10-11	2023-11-11	3300000	unpaid
182	6	\N	\N	2023-11-11	2023-12-11	3300000	unpaid
183	6	\N	\N	2023-12-11	2024-01-11	3300000	unpaid
184	6	\N	\N	2024-01-11	2024-02-11	3300000	unpaid
185	6	\N	\N	2024-02-11	2024-03-11	3300000	unpaid
186	6	\N	\N	2024-03-11	2024-04-11	3300000	unpaid
187	6	\N	\N	2024-04-11	2024-05-11	3300000	unpaid
188	6	\N	\N	2024-05-11	2024-06-11	3300000	unpaid
189	6	\N	\N	2024-06-11	2024-07-11	3300000	unpaid
190	6	\N	\N	2024-07-11	2024-08-11	3300000	unpaid
191	6	\N	\N	2024-08-11	2024-09-11	3300000	unpaid
192	6	\N	\N	2024-09-11	2024-10-11	3300000	unpaid
193	6	\N	\N	2024-10-11	2024-11-11	3300000	unpaid
194	6	\N	\N	2024-11-11	2024-12-11	3300000	unpaid
195	6	\N	\N	2024-12-11	2025-01-11	3300000	unpaid
196	6	\N	\N	2025-01-11	2025-02-11	3300000	unpaid
197	6	\N	\N	2025-02-11	2025-03-11	3300000	unpaid
198	6	\N	\N	2025-03-11	2025-04-11	3300000	unpaid
199	6	\N	\N	2025-04-11	2025-05-11	3300000	unpaid
200	6	\N	\N	2025-05-11	2025-06-11	3300000	unpaid
201	6	\N	\N	2025-06-11	2025-07-11	3300000	unpaid
202	6	\N	\N	2025-07-11	2025-08-11	3300000	unpaid
203	6	\N	\N	2025-08-11	2025-09-11	3300000	unpaid
204	6	\N	\N	2025-09-11	2025-10-11	3300000	unpaid
205	6	\N	\N	2025-10-11	2025-11-11	3300000	unpaid
206	6	\N	\N	2025-11-11	2025-12-11	3300000	unpaid
207	6	\N	\N	2025-12-11	2026-01-11	3300000	unpaid
208	6	\N	\N	2026-01-11	2026-02-11	3300000	unpaid
209	6	\N	\N	2026-02-11	2026-03-11	3300000	unpaid
210	6	\N	\N	2026-03-11	2026-04-11	3300000	unpaid
211	6	\N	\N	2026-04-11	2026-05-11	3300000	unpaid
212	6	\N	\N	2026-05-11	2026-06-11	3300000	unpaid
213	6	\N	\N	2026-06-11	2026-07-11	3300000	unpaid
214	6	\N	\N	2026-07-11	2026-08-11	3300000	unpaid
215	6	\N	\N	2026-08-11	2026-09-11	3300000	unpaid
216	6	\N	\N	2026-09-11	2026-10-11	3300000	unpaid
250	7	\N	\N	2023-02-17	2023-03-17	5800000	unpaid
251	7	\N	\N	2023-03-17	2023-04-17	5800000	unpaid
252	7	\N	\N	2023-04-17	2023-05-17	5800000	unpaid
253	7	\N	\N	2023-05-17	2023-06-17	5800000	unpaid
254	7	\N	\N	2023-06-17	2023-07-17	5800000	unpaid
255	7	\N	\N	2023-07-17	2023-08-17	5800000	unpaid
256	7	\N	\N	2023-08-17	2023-09-17	5800000	unpaid
257	7	\N	\N	2023-09-17	2023-10-17	5800000	unpaid
258	7	\N	\N	2023-10-17	2023-11-17	5800000	unpaid
259	7	\N	\N	2023-11-17	2023-12-17	5800000	unpaid
260	7	\N	\N	2023-12-17	2024-01-17	5800000	unpaid
261	7	\N	\N	2024-01-17	2024-02-17	5800000	unpaid
262	7	\N	\N	2024-02-17	2024-03-17	5800000	unpaid
263	7	\N	\N	2024-03-17	2024-04-17	5800000	unpaid
264	7	\N	\N	2024-04-17	2024-05-17	5800000	unpaid
265	7	\N	\N	2024-05-17	2024-06-17	5800000	unpaid
266	7	\N	\N	2024-06-17	2024-07-17	5800000	unpaid
267	7	\N	\N	2024-07-17	2024-08-17	5800000	unpaid
268	7	\N	\N	2024-08-17	2024-09-17	5800000	unpaid
269	7	\N	\N	2024-09-17	2024-10-17	5800000	unpaid
270	7	\N	\N	2024-10-17	2024-11-17	5800000	unpaid
271	7	\N	\N	2024-11-17	2024-12-17	5800000	unpaid
272	7	\N	\N	2024-12-17	2025-01-17	5800000	unpaid
62	3	2023-01-14	cash	2023-01-21	2023-02-21	1300000	paid
100	4	2018-06-08	cash	2018-06-15	2018-07-15	9600000	paid
101	4	2018-07-08	cash	2018-07-15	2018-08-15	9600000	paid
102	4	2018-08-08	cash	2018-08-15	2018-09-15	9600000	paid
103	4	2018-09-08	cash	2018-09-15	2018-10-15	9600000	paid
104	4	2018-10-08	cash	2018-10-15	2018-11-15	9600000	paid
273	7	\N	\N	2025-01-17	2025-02-17	5800000	unpaid
274	7	\N	\N	2025-02-17	2025-03-17	5800000	unpaid
275	7	\N	\N	2025-03-17	2025-04-17	5800000	unpaid
276	7	\N	\N	2025-04-17	2025-05-17	5800000	unpaid
327	10	\N	\N	2023-02-27	2023-03-27	4300000	unpaid
328	10	\N	\N	2023-03-27	2023-04-27	4300000	unpaid
329	10	\N	\N	2023-04-27	2023-05-27	4300000	unpaid
330	10	\N	\N	2023-05-27	2023-06-27	4300000	unpaid
331	10	\N	\N	2023-06-27	2023-07-27	4300000	unpaid
332	10	\N	\N	2023-07-27	2023-08-27	4300000	unpaid
333	10	\N	\N	2023-08-27	2023-09-27	4300000	unpaid
334	10	\N	\N	2023-09-27	2023-10-27	4300000	unpaid
335	10	\N	\N	2023-10-27	2023-11-27	4300000	unpaid
336	10	\N	\N	2023-11-27	2023-12-27	4300000	unpaid
337	10	\N	\N	2023-12-27	2024-01-27	4300000	unpaid
338	10	\N	\N	2024-01-27	2024-02-27	4300000	unpaid
339	10	\N	\N	2024-02-27	2024-03-27	4300000	unpaid
340	10	\N	\N	2024-03-27	2024-04-27	4300000	unpaid
341	10	\N	\N	2024-04-27	2024-05-27	4300000	unpaid
342	10	\N	\N	2024-05-27	2024-06-27	4300000	unpaid
343	10	\N	\N	2024-06-27	2024-07-27	4300000	unpaid
344	10	\N	\N	2024-07-27	2024-08-27	4300000	unpaid
345	10	\N	\N	2024-08-27	2024-09-27	4300000	unpaid
346	10	\N	\N	2024-09-27	2024-10-27	4300000	unpaid
347	10	\N	\N	2024-10-27	2024-11-27	4300000	unpaid
348	10	\N	\N	2024-11-27	2024-12-27	4300000	unpaid
378	11	\N	\N	2023-02-24	2023-03-24	8300000	unpaid
379	11	\N	\N	2023-03-24	2023-04-24	8300000	unpaid
380	11	\N	\N	2023-04-24	2023-05-24	8300000	unpaid
381	11	\N	\N	2023-05-24	2023-06-24	8300000	unpaid
382	11	\N	\N	2023-06-24	2023-07-24	8300000	unpaid
383	11	\N	\N	2023-07-24	2023-08-24	8300000	unpaid
384	11	\N	\N	2023-08-24	2023-09-24	8300000	unpaid
385	11	\N	\N	2023-09-24	2023-10-24	8300000	unpaid
386	11	\N	\N	2023-10-24	2023-11-24	8300000	unpaid
387	11	\N	\N	2023-11-24	2023-12-24	8300000	unpaid
388	11	\N	\N	2023-12-24	2024-01-24	8300000	unpaid
389	11	\N	\N	2024-01-24	2024-02-24	8300000	unpaid
390	11	\N	\N	2024-02-24	2024-03-24	8300000	unpaid
391	11	\N	\N	2024-03-24	2024-04-24	8300000	unpaid
392	11	\N	\N	2024-04-24	2024-05-24	8300000	unpaid
393	11	\N	\N	2024-05-24	2024-06-24	8300000	unpaid
394	11	\N	\N	2024-06-24	2024-07-24	8300000	unpaid
395	11	\N	\N	2024-07-24	2024-08-24	8300000	unpaid
396	11	\N	\N	2024-08-24	2024-09-24	8300000	unpaid
402	12	\N	\N	2023-02-22	2023-03-22	7700000	unpaid
403	12	\N	\N	2023-03-22	2023-04-22	7700000	unpaid
404	12	\N	\N	2023-04-22	2023-05-22	7700000	unpaid
405	12	\N	\N	2023-05-22	2023-06-22	7700000	unpaid
406	12	\N	\N	2023-06-22	2023-07-22	7700000	unpaid
407	12	\N	\N	2023-07-22	2023-08-22	7700000	unpaid
408	12	\N	\N	2023-08-22	2023-09-22	7700000	unpaid
105	4	2018-11-08	cash	2018-11-15	2018-12-15	9600000	paid
106	4	2018-12-08	cash	2018-12-15	2019-01-15	9600000	paid
107	4	2019-01-08	cash	2019-01-15	2019-02-15	9600000	paid
108	4	2019-02-08	cash	2019-02-15	2019-03-15	9600000	paid
109	4	2019-03-08	cash	2019-03-15	2019-04-15	9600000	paid
409	12	\N	\N	2023-09-22	2023-10-22	7700000	unpaid
410	12	\N	\N	2023-10-22	2023-11-22	7700000	unpaid
411	12	\N	\N	2023-11-22	2023-12-22	7700000	unpaid
412	12	\N	\N	2023-12-22	2024-01-22	7700000	unpaid
413	12	\N	\N	2024-01-22	2024-02-22	7700000	unpaid
414	12	\N	\N	2024-02-22	2024-03-22	7700000	unpaid
415	12	\N	\N	2024-03-22	2024-04-22	7700000	unpaid
416	12	\N	\N	2024-04-22	2024-05-22	7700000	unpaid
417	12	\N	\N	2024-05-22	2024-06-22	7700000	unpaid
418	12	\N	\N	2024-06-22	2024-07-22	7700000	unpaid
419	12	\N	\N	2024-07-22	2024-08-22	7700000	unpaid
420	12	\N	\N	2024-08-22	2024-09-22	7700000	unpaid
459	13	\N	\N	2023-02-28	2023-03-28	3400000	unpaid
460	13	\N	\N	2023-03-28	2023-04-28	3400000	unpaid
461	13	\N	\N	2023-04-28	2023-05-28	3400000	unpaid
462	13	\N	\N	2023-05-28	2023-06-28	3400000	unpaid
463	13	\N	\N	2023-06-28	2023-07-28	3400000	unpaid
464	13	\N	\N	2023-07-28	2023-08-28	3400000	unpaid
465	13	\N	\N	2023-08-28	2023-09-28	3400000	unpaid
466	13	\N	\N	2023-09-28	2023-10-28	3400000	unpaid
467	13	\N	\N	2023-10-28	2023-11-28	3400000	unpaid
468	13	\N	\N	2023-11-28	2023-12-28	3400000	unpaid
508	14	\N	\N	2023-02-02	2023-03-02	1100000	unpaid
509	14	\N	\N	2023-03-02	2023-04-02	1100000	unpaid
510	14	\N	\N	2023-04-02	2023-05-02	1100000	unpaid
511	14	\N	\N	2023-05-02	2023-06-02	1100000	unpaid
512	14	\N	\N	2023-06-02	2023-07-02	1100000	unpaid
513	14	\N	\N	2023-07-02	2023-08-02	1100000	unpaid
514	14	\N	\N	2023-08-02	2023-09-02	1100000	unpaid
515	14	\N	\N	2023-09-02	2023-10-02	1100000	unpaid
516	14	\N	\N	2023-10-02	2023-11-02	1100000	unpaid
517	14	\N	\N	2023-11-02	2023-12-02	1100000	unpaid
518	14	\N	\N	2023-12-02	2024-01-02	1100000	unpaid
519	14	\N	\N	2024-01-02	2024-02-02	1100000	unpaid
520	14	\N	\N	2024-02-02	2024-03-02	1100000	unpaid
521	14	\N	\N	2024-03-02	2024-04-02	1100000	unpaid
522	14	\N	\N	2024-04-02	2024-05-02	1100000	unpaid
523	14	\N	\N	2024-05-02	2024-06-02	1100000	unpaid
524	14	\N	\N	2024-06-02	2024-07-02	1100000	unpaid
525	14	\N	\N	2024-07-02	2024-08-02	1100000	unpaid
526	14	\N	\N	2024-08-02	2024-09-02	1100000	unpaid
527	14	\N	\N	2024-09-02	2024-10-02	1100000	unpaid
528	14	\N	\N	2024-10-02	2024-11-02	1100000	unpaid
110	4	2019-04-08	cash	2019-04-15	2019-05-15	9600000	paid
111	4	2019-05-08	cash	2019-05-15	2019-06-15	9600000	paid
112	4	2019-06-08	cash	2019-06-15	2019-07-15	9600000	paid
575	15	\N	\N	2023-02-15	2023-03-15	1200000	unpaid
576	15	\N	\N	2023-03-15	2023-04-15	1200000	unpaid
577	15	\N	\N	2023-04-15	2023-05-15	1200000	unpaid
578	15	\N	\N	2023-05-15	2023-06-15	1200000	unpaid
579	15	\N	\N	2023-06-15	2023-07-15	1200000	unpaid
580	15	\N	\N	2023-07-15	2023-08-15	1200000	unpaid
581	15	\N	\N	2023-08-15	2023-09-15	1200000	unpaid
582	15	\N	\N	2023-09-15	2023-10-15	1200000	unpaid
583	15	\N	\N	2023-10-15	2023-11-15	1200000	unpaid
584	15	\N	\N	2023-11-15	2023-12-15	1200000	unpaid
585	15	\N	\N	2023-12-15	2024-01-15	1200000	unpaid
586	15	\N	\N	2024-01-15	2024-02-15	1200000	unpaid
587	15	\N	\N	2024-02-15	2024-03-15	1200000	unpaid
588	15	\N	\N	2024-03-15	2024-04-15	1200000	unpaid
595	16	\N	\N	2023-02-04	2023-03-04	7500000	unpaid
596	16	\N	\N	2023-03-04	2023-04-04	7500000	unpaid
597	16	\N	\N	2023-04-04	2023-05-04	7500000	unpaid
598	16	\N	\N	2023-05-04	2023-06-04	7500000	unpaid
599	16	\N	\N	2023-06-04	2023-07-04	7500000	unpaid
600	16	\N	\N	2023-07-04	2023-08-04	7500000	unpaid
601	16	\N	\N	2023-08-04	2023-09-04	7500000	unpaid
602	16	\N	\N	2023-09-04	2023-10-04	7500000	unpaid
603	16	\N	\N	2023-10-04	2023-11-04	7500000	unpaid
604	16	\N	\N	2023-11-04	2023-12-04	7500000	unpaid
605	16	\N	\N	2023-12-04	2024-01-04	7500000	unpaid
606	16	\N	\N	2024-01-04	2024-02-04	7500000	unpaid
607	16	\N	\N	2024-02-04	2024-03-04	7500000	unpaid
608	16	\N	\N	2024-03-04	2024-04-04	7500000	unpaid
609	16	\N	\N	2024-04-04	2024-05-04	7500000	unpaid
610	16	\N	\N	2024-05-04	2024-06-04	7500000	unpaid
611	16	\N	\N	2024-06-04	2024-07-04	7500000	unpaid
612	16	\N	\N	2024-07-04	2024-08-04	7500000	unpaid
613	16	\N	\N	2024-08-04	2024-09-04	7500000	unpaid
614	16	\N	\N	2024-09-04	2024-10-04	7500000	unpaid
615	16	\N	\N	2024-10-04	2024-11-04	7500000	unpaid
616	16	\N	\N	2024-11-04	2024-12-04	7500000	unpaid
617	16	\N	\N	2024-12-04	2025-01-04	7500000	unpaid
618	16	\N	\N	2025-01-04	2025-02-04	7500000	unpaid
619	16	\N	\N	2025-02-04	2025-03-04	7500000	unpaid
620	16	\N	\N	2025-03-04	2025-04-04	7500000	unpaid
621	16	\N	\N	2025-04-04	2025-05-04	7500000	unpaid
622	16	\N	\N	2025-05-04	2025-06-04	7500000	unpaid
623	16	\N	\N	2025-06-04	2025-07-04	7500000	unpaid
624	16	\N	\N	2025-07-04	2025-08-04	7500000	unpaid
625	16	\N	\N	2025-08-04	2025-09-04	7500000	unpaid
626	16	\N	\N	2025-09-04	2025-10-04	7500000	unpaid
627	16	\N	\N	2025-10-04	2025-11-04	7500000	unpaid
628	16	\N	\N	2025-11-04	2025-12-04	7500000	unpaid
629	16	\N	\N	2025-12-04	2026-01-04	7500000	unpaid
630	16	\N	\N	2026-01-04	2026-02-04	7500000	unpaid
631	16	\N	\N	2026-02-04	2026-03-04	7500000	unpaid
632	16	\N	\N	2026-03-04	2026-04-04	7500000	unpaid
633	16	\N	\N	2026-04-04	2026-05-04	7500000	unpaid
634	16	\N	\N	2026-05-04	2026-06-04	7500000	unpaid
635	16	\N	\N	2026-06-04	2026-07-04	7500000	unpaid
636	16	\N	\N	2026-07-04	2026-08-04	7500000	unpaid
637	16	\N	\N	2026-08-04	2026-09-04	7500000	unpaid
638	16	\N	\N	2026-09-04	2026-10-04	7500000	unpaid
639	16	\N	\N	2026-10-04	2026-11-04	7500000	unpaid
640	16	\N	\N	2026-11-04	2026-12-04	7500000	unpaid
641	16	\N	\N	2026-12-04	2027-01-04	7500000	unpaid
642	16	\N	\N	2027-01-04	2027-02-04	7500000	unpaid
643	16	\N	\N	2027-02-04	2027-03-04	7500000	unpaid
644	16	\N	\N	2027-03-04	2027-04-04	7500000	unpaid
645	16	\N	\N	2027-04-04	2027-05-04	7500000	unpaid
646	16	\N	\N	2027-05-04	2027-06-04	7500000	unpaid
647	16	\N	\N	2027-06-04	2027-07-04	7500000	unpaid
648	16	\N	\N	2027-07-04	2027-08-04	7500000	unpaid
113	4	2019-07-08	cash	2019-07-15	2019-08-15	9600000	paid
114	4	2019-08-08	cash	2019-08-15	2019-09-15	9600000	paid
115	4	2019-09-08	cash	2019-09-15	2019-10-15	9600000	paid
691	17	\N	\N	2023-02-11	2023-03-11	9200000	unpaid
692	17	\N	\N	2023-03-11	2023-04-11	9200000	unpaid
693	17	\N	\N	2023-04-11	2023-05-11	9200000	unpaid
694	17	\N	\N	2023-05-11	2023-06-11	9200000	unpaid
695	17	\N	\N	2023-06-11	2023-07-11	9200000	unpaid
696	17	\N	\N	2023-07-11	2023-08-11	9200000	unpaid
721	18	\N	\N	2023-02-19	2023-03-19	7400000	unpaid
722	18	\N	\N	2023-03-19	2023-04-19	7400000	unpaid
723	18	\N	\N	2023-04-19	2023-05-19	7400000	unpaid
724	18	\N	\N	2023-05-19	2023-06-19	7400000	unpaid
725	18	\N	\N	2023-06-19	2023-07-19	7400000	unpaid
726	18	\N	\N	2023-07-19	2023-08-19	7400000	unpaid
727	18	\N	\N	2023-08-19	2023-09-19	7400000	unpaid
728	18	\N	\N	2023-09-19	2023-10-19	7400000	unpaid
729	18	\N	\N	2023-10-19	2023-11-19	7400000	unpaid
730	18	\N	\N	2023-11-19	2023-12-19	7400000	unpaid
731	18	\N	\N	2023-12-19	2024-01-19	7400000	unpaid
732	18	\N	\N	2024-01-19	2024-02-19	7400000	unpaid
733	18	\N	\N	2024-02-19	2024-03-19	7400000	unpaid
734	18	\N	\N	2024-03-19	2024-04-19	7400000	unpaid
735	18	\N	\N	2024-04-19	2024-05-19	7400000	unpaid
736	18	\N	\N	2024-05-19	2024-06-19	7400000	unpaid
737	18	\N	\N	2024-06-19	2024-07-19	7400000	unpaid
738	18	\N	\N	2024-07-19	2024-08-19	7400000	unpaid
739	18	\N	\N	2024-08-19	2024-09-19	7400000	unpaid
740	18	\N	\N	2024-09-19	2024-10-19	7400000	unpaid
741	18	\N	\N	2024-10-19	2024-11-19	7400000	unpaid
742	18	\N	\N	2024-11-19	2024-12-19	7400000	unpaid
743	18	\N	\N	2024-12-19	2025-01-19	7400000	unpaid
744	18	\N	\N	2025-01-19	2025-02-19	7400000	unpaid
775	20	\N	\N	2023-02-17	2023-03-17	6600000	unpaid
776	20	\N	\N	2023-03-17	2023-04-17	6600000	unpaid
777	20	\N	\N	2023-04-17	2023-05-17	6600000	unpaid
778	20	\N	\N	2023-05-17	2023-06-17	6600000	unpaid
779	20	\N	\N	2023-06-17	2023-07-17	6600000	unpaid
780	20	\N	\N	2023-07-17	2023-08-17	6600000	unpaid
781	20	\N	\N	2023-08-17	2023-09-17	6600000	unpaid
782	20	\N	\N	2023-09-17	2023-10-17	6600000	unpaid
783	20	\N	\N	2023-10-17	2023-11-17	6600000	unpaid
784	20	\N	\N	2023-11-17	2023-12-17	6600000	unpaid
785	20	\N	\N	2023-12-17	2024-01-17	6600000	unpaid
786	20	\N	\N	2024-01-17	2024-02-17	6600000	unpaid
787	20	\N	\N	2024-02-17	2024-03-17	6600000	unpaid
788	20	\N	\N	2024-03-17	2024-04-17	6600000	unpaid
789	20	\N	\N	2024-04-17	2024-05-17	6600000	unpaid
790	20	\N	\N	2024-05-17	2024-06-17	6600000	unpaid
791	20	\N	\N	2024-06-17	2024-07-17	6600000	unpaid
792	20	\N	\N	2024-07-17	2024-08-17	6600000	unpaid
793	20	\N	\N	2024-08-17	2024-09-17	6600000	unpaid
794	20	\N	\N	2024-09-17	2024-10-17	6600000	unpaid
795	20	\N	\N	2024-10-17	2024-11-17	6600000	unpaid
796	20	\N	\N	2024-11-17	2024-12-17	6600000	unpaid
797	20	\N	\N	2024-12-17	2025-01-17	6600000	unpaid
798	20	\N	\N	2025-01-17	2025-02-17	6600000	unpaid
799	20	\N	\N	2025-02-17	2025-03-17	6600000	unpaid
800	20	\N	\N	2025-03-17	2025-04-17	6600000	unpaid
801	20	\N	\N	2025-04-17	2025-05-17	6600000	unpaid
802	20	\N	\N	2025-05-17	2025-06-17	6600000	unpaid
803	20	\N	\N	2025-06-17	2025-07-17	6600000	unpaid
804	20	\N	\N	2025-07-17	2025-08-17	6600000	unpaid
805	20	\N	\N	2025-08-17	2025-09-17	6600000	unpaid
806	20	\N	\N	2025-09-17	2025-10-17	6600000	unpaid
807	20	\N	\N	2025-10-17	2025-11-17	6600000	unpaid
808	20	\N	\N	2025-11-17	2025-12-17	6600000	unpaid
809	20	\N	\N	2025-12-17	2026-01-17	6600000	unpaid
810	20	\N	\N	2026-01-17	2026-02-17	6600000	unpaid
811	20	\N	\N	2026-02-17	2026-03-17	6600000	unpaid
812	20	\N	\N	2026-03-17	2026-04-17	6600000	unpaid
813	20	\N	\N	2026-04-17	2026-05-17	6600000	unpaid
814	20	\N	\N	2026-05-17	2026-06-17	6600000	unpaid
815	20	\N	\N	2026-06-17	2026-07-17	6600000	unpaid
816	20	\N	\N	2026-07-17	2026-08-17	6600000	unpaid
116	4	2019-10-08	cash	2019-10-15	2019-11-15	9600000	paid
117	4	2019-11-08	cash	2019-11-15	2019-12-15	9600000	paid
118	4	2019-12-08	cash	2019-12-15	2020-01-15	9600000	paid
119	4	2020-01-08	cash	2020-01-15	2020-02-15	9600000	paid
120	4	2020-02-08	cash	2020-02-15	2020-03-15	9600000	paid
817	20	\N	\N	2026-08-17	2026-09-17	6600000	unpaid
818	20	\N	\N	2026-09-17	2026-10-17	6600000	unpaid
819	20	\N	\N	2026-10-17	2026-11-17	6600000	unpaid
820	20	\N	\N	2026-11-17	2026-12-17	6600000	unpaid
821	20	\N	\N	2026-12-17	2027-01-17	6600000	unpaid
822	20	\N	\N	2027-01-17	2027-02-17	6600000	unpaid
823	20	\N	\N	2027-02-17	2027-03-17	6600000	unpaid
824	20	\N	\N	2027-03-17	2027-04-17	6600000	unpaid
825	20	\N	\N	2027-04-17	2027-05-17	6600000	unpaid
826	20	\N	\N	2027-05-17	2027-06-17	6600000	unpaid
827	20	\N	\N	2027-06-17	2027-07-17	6600000	unpaid
828	20	\N	\N	2027-07-17	2027-08-17	6600000	unpaid
867	23	\N	\N	2023-02-16	2023-03-16	3700000	unpaid
868	23	\N	\N	2023-03-16	2023-04-16	3700000	unpaid
869	23	\N	\N	2023-04-16	2023-05-16	3700000	unpaid
870	23	\N	\N	2023-05-16	2023-06-16	3700000	unpaid
871	23	\N	\N	2023-06-16	2023-07-16	3700000	unpaid
872	23	\N	\N	2023-07-16	2023-08-16	3700000	unpaid
873	23	\N	\N	2023-08-16	2023-09-16	3700000	unpaid
874	23	\N	\N	2023-09-16	2023-10-16	3700000	unpaid
875	23	\N	\N	2023-10-16	2023-11-16	3700000	unpaid
876	23	\N	\N	2023-11-16	2023-12-16	3700000	unpaid
877	23	\N	\N	2023-12-16	2024-01-16	3700000	unpaid
878	23	\N	\N	2024-01-16	2024-02-16	3700000	unpaid
879	23	\N	\N	2024-02-16	2024-03-16	3700000	unpaid
880	23	\N	\N	2024-03-16	2024-04-16	3700000	unpaid
881	23	\N	\N	2024-04-16	2024-05-16	3700000	unpaid
882	23	\N	\N	2024-05-16	2024-06-16	3700000	unpaid
883	23	\N	\N	2024-06-16	2024-07-16	3700000	unpaid
884	23	\N	\N	2024-07-16	2024-08-16	3700000	unpaid
885	23	\N	\N	2024-08-16	2024-09-16	3700000	unpaid
886	23	\N	\N	2024-09-16	2024-10-16	3700000	unpaid
887	23	\N	\N	2024-10-16	2024-11-16	3700000	unpaid
888	23	\N	\N	2024-11-16	2024-12-16	3700000	unpaid
889	23	\N	\N	2024-12-16	2025-01-16	3700000	unpaid
890	23	\N	\N	2025-01-16	2025-02-16	3700000	unpaid
891	23	\N	\N	2025-02-16	2025-03-16	3700000	unpaid
892	23	\N	\N	2025-03-16	2025-04-16	3700000	unpaid
893	23	\N	\N	2025-04-16	2025-05-16	3700000	unpaid
894	23	\N	\N	2025-05-16	2025-06-16	3700000	unpaid
895	23	\N	\N	2025-06-16	2025-07-16	3700000	unpaid
896	23	\N	\N	2025-07-16	2025-08-16	3700000	unpaid
897	23	\N	\N	2025-08-16	2025-09-16	3700000	unpaid
898	23	\N	\N	2025-09-16	2025-10-16	3700000	unpaid
899	23	\N	\N	2025-10-16	2025-11-16	3700000	unpaid
900	23	\N	\N	2025-11-16	2025-12-16	3700000	unpaid
121	4	2020-03-08	cash	2020-03-15	2020-04-15	9600000	paid
972	25	\N	\N	2023-02-26	2023-03-26	800000	unpaid
973	25	\N	\N	2023-03-26	2023-04-26	800000	unpaid
974	25	\N	\N	2023-04-26	2023-05-26	800000	unpaid
975	25	\N	\N	2023-05-26	2023-06-26	800000	unpaid
976	25	\N	\N	2023-06-26	2023-07-26	800000	unpaid
977	25	\N	\N	2023-07-26	2023-08-26	800000	unpaid
978	25	\N	\N	2023-08-26	2023-09-26	800000	unpaid
979	25	\N	\N	2023-09-26	2023-10-26	800000	unpaid
980	25	\N	\N	2023-10-26	2023-11-26	800000	unpaid
981	25	\N	\N	2023-11-26	2023-12-26	800000	unpaid
982	25	\N	\N	2023-12-26	2024-01-26	800000	unpaid
983	25	\N	\N	2024-01-26	2024-02-26	800000	unpaid
984	25	\N	\N	2024-02-26	2024-03-26	800000	unpaid
985	25	\N	\N	2024-03-26	2024-04-26	800000	unpaid
986	25	\N	\N	2024-04-26	2024-05-26	800000	unpaid
987	25	\N	\N	2024-05-26	2024-06-26	800000	unpaid
988	25	\N	\N	2024-06-26	2024-07-26	800000	unpaid
989	25	\N	\N	2024-07-26	2024-08-26	800000	unpaid
990	25	\N	\N	2024-08-26	2024-09-26	800000	unpaid
991	25	\N	\N	2024-09-26	2024-10-26	800000	unpaid
992	25	\N	\N	2024-10-26	2024-11-26	800000	unpaid
993	25	\N	\N	2024-11-26	2024-12-26	800000	unpaid
994	25	\N	\N	2024-12-26	2025-01-26	800000	unpaid
995	25	\N	\N	2025-01-26	2025-02-26	800000	unpaid
996	25	\N	\N	2025-02-26	2025-03-26	800000	unpaid
1011	26	\N	\N	2023-02-28	2023-03-28	1400000	unpaid
1012	26	\N	\N	2023-03-28	2023-04-28	1400000	unpaid
1013	26	\N	\N	2023-04-28	2023-05-28	1400000	unpaid
1014	26	\N	\N	2023-05-28	2023-06-28	1400000	unpaid
1015	26	\N	\N	2023-06-28	2023-07-28	1400000	unpaid
1016	26	\N	\N	2023-07-28	2023-08-28	1400000	unpaid
1017	26	\N	\N	2023-08-28	2023-09-28	1400000	unpaid
1018	26	\N	\N	2023-09-28	2023-10-28	1400000	unpaid
1019	26	\N	\N	2023-10-28	2023-11-28	1400000	unpaid
1020	26	\N	\N	2023-11-28	2023-12-28	1400000	unpaid
1021	26	\N	\N	2023-12-28	2024-01-28	1400000	unpaid
1022	26	\N	\N	2024-01-28	2024-02-28	1400000	unpaid
1023	26	\N	\N	2024-02-28	2024-03-28	1400000	unpaid
1024	26	\N	\N	2024-03-28	2024-04-28	1400000	unpaid
1025	26	\N	\N	2024-04-28	2024-05-28	1400000	unpaid
1026	26	\N	\N	2024-05-28	2024-06-28	1400000	unpaid
1027	26	\N	\N	2024-06-28	2024-07-28	1400000	unpaid
1028	26	\N	\N	2024-07-28	2024-08-28	1400000	unpaid
1029	26	\N	\N	2024-08-28	2024-09-28	1400000	unpaid
1030	26	\N	\N	2024-09-28	2024-10-28	1400000	unpaid
1031	26	\N	\N	2024-10-28	2024-11-28	1400000	unpaid
1032	26	\N	\N	2024-11-28	2024-12-28	1400000	unpaid
1033	26	\N	\N	2024-12-28	2025-01-28	1400000	unpaid
1034	26	\N	\N	2025-01-28	2025-02-28	1400000	unpaid
1035	26	\N	\N	2025-02-28	2025-03-28	1400000	unpaid
1036	26	\N	\N	2025-03-28	2025-04-28	1400000	unpaid
1037	26	\N	\N	2025-04-28	2025-05-28	1400000	unpaid
1038	26	\N	\N	2025-05-28	2025-06-28	1400000	unpaid
1039	26	\N	\N	2025-06-28	2025-07-28	1400000	unpaid
1040	26	\N	\N	2025-07-28	2025-08-28	1400000	unpaid
1041	26	\N	\N	2025-08-28	2025-09-28	1400000	unpaid
1042	26	\N	\N	2025-09-28	2025-10-28	1400000	unpaid
1043	26	\N	\N	2025-10-28	2025-11-28	1400000	unpaid
1044	26	\N	\N	2025-11-28	2025-12-28	1400000	unpaid
1071	27	\N	\N	2023-02-12	2023-03-12	2200000	unpaid
1072	27	\N	\N	2023-03-12	2023-04-12	2200000	unpaid
1073	27	\N	\N	2023-04-12	2023-05-12	2200000	unpaid
1074	27	\N	\N	2023-05-12	2023-06-12	2200000	unpaid
1075	27	\N	\N	2023-06-12	2023-07-12	2200000	unpaid
1076	27	\N	\N	2023-07-12	2023-08-12	2200000	unpaid
1077	27	\N	\N	2023-08-12	2023-09-12	2200000	unpaid
1078	27	\N	\N	2023-09-12	2023-10-12	2200000	unpaid
1079	27	\N	\N	2023-10-12	2023-11-12	2200000	unpaid
1080	27	\N	\N	2023-11-12	2023-12-12	2200000	unpaid
122	4	2020-04-08	cash	2020-04-15	2020-05-15	9600000	paid
123	4	2020-05-08	cash	2020-05-15	2020-06-15	9600000	paid
124	4	2020-06-08	cash	2020-06-15	2020-07-15	9600000	paid
125	4	2020-07-08	cash	2020-07-15	2020-08-15	9600000	paid
126	4	2020-08-08	cash	2020-08-15	2020-09-15	9600000	paid
1119	29	\N	\N	2023-02-12	2023-03-12	1900000	unpaid
1120	29	\N	\N	2023-03-12	2023-04-12	1900000	unpaid
1121	29	\N	\N	2023-04-12	2023-05-12	1900000	unpaid
1122	29	\N	\N	2023-05-12	2023-06-12	1900000	unpaid
1123	29	\N	\N	2023-06-12	2023-07-12	1900000	unpaid
1124	29	\N	\N	2023-07-12	2023-08-12	1900000	unpaid
1125	29	\N	\N	2023-08-12	2023-09-12	1900000	unpaid
1126	29	\N	\N	2023-09-12	2023-10-12	1900000	unpaid
1127	29	\N	\N	2023-10-12	2023-11-12	1900000	unpaid
1128	29	\N	\N	2023-11-12	2023-12-12	1900000	unpaid
1129	29	\N	\N	2023-12-12	2024-01-12	1900000	unpaid
1130	29	\N	\N	2024-01-12	2024-02-12	1900000	unpaid
1131	29	\N	\N	2024-02-12	2024-03-12	1900000	unpaid
1132	29	\N	\N	2024-03-12	2024-04-12	1900000	unpaid
1133	29	\N	\N	2024-04-12	2024-05-12	1900000	unpaid
1134	29	\N	\N	2024-05-12	2024-06-12	1900000	unpaid
1135	29	\N	\N	2024-06-12	2024-07-12	1900000	unpaid
1136	29	\N	\N	2024-07-12	2024-08-12	1900000	unpaid
1137	29	\N	\N	2024-08-12	2024-09-12	1900000	unpaid
1138	29	\N	\N	2024-09-12	2024-10-12	1900000	unpaid
1139	29	\N	\N	2024-10-12	2024-11-12	1900000	unpaid
1140	29	\N	\N	2024-11-12	2024-12-12	1900000	unpaid
1141	29	\N	\N	2024-12-12	2025-01-12	1900000	unpaid
1142	29	\N	\N	2025-01-12	2025-02-12	1900000	unpaid
1143	29	\N	\N	2025-02-12	2025-03-12	1900000	unpaid
1144	29	\N	\N	2025-03-12	2025-04-12	1900000	unpaid
1145	29	\N	\N	2025-04-12	2025-05-12	1900000	unpaid
1146	29	\N	\N	2025-05-12	2025-06-12	1900000	unpaid
1147	29	\N	\N	2025-06-12	2025-07-12	1900000	unpaid
1148	29	\N	\N	2025-07-12	2025-08-12	1900000	unpaid
1149	29	\N	\N	2025-08-12	2025-09-12	1900000	unpaid
1150	29	\N	\N	2025-09-12	2025-10-12	1900000	unpaid
1151	29	\N	\N	2025-10-12	2025-11-12	1900000	unpaid
1152	29	\N	\N	2025-11-12	2025-12-12	1900000	unpaid
127	4	2020-09-08	cash	2020-09-15	2020-10-15	9600000	paid
128	4	2020-10-08	cash	2020-10-15	2020-11-15	9600000	paid
129	4	2020-11-08	cash	2020-11-15	2020-12-15	9600000	paid
1252	35	\N	\N	2023-02-27	2023-03-27	1400000	unpaid
1253	35	\N	\N	2023-03-27	2023-04-27	1400000	unpaid
1254	35	\N	\N	2023-04-27	2023-05-27	1400000	unpaid
1255	35	\N	\N	2023-05-27	2023-06-27	1400000	unpaid
1256	35	\N	\N	2023-06-27	2023-07-27	1400000	unpaid
1257	35	\N	\N	2023-07-27	2023-08-27	1400000	unpaid
1258	35	\N	\N	2023-08-27	2023-09-27	1400000	unpaid
1259	35	\N	\N	2023-09-27	2023-10-27	1400000	unpaid
1260	35	\N	\N	2023-10-27	2023-11-27	1400000	unpaid
1261	35	\N	\N	2023-11-27	2023-12-27	1400000	unpaid
1262	35	\N	\N	2023-12-27	2024-01-27	1400000	unpaid
1263	35	\N	\N	2024-01-27	2024-02-27	1400000	unpaid
1264	35	\N	\N	2024-02-27	2024-03-27	1400000	unpaid
1265	35	\N	\N	2024-03-27	2024-04-27	1400000	unpaid
1266	35	\N	\N	2024-04-27	2024-05-27	1400000	unpaid
1267	35	\N	\N	2024-05-27	2024-06-27	1400000	unpaid
1268	35	\N	\N	2024-06-27	2024-07-27	1400000	unpaid
1269	35	\N	\N	2024-07-27	2024-08-27	1400000	unpaid
1270	35	\N	\N	2024-08-27	2024-09-27	1400000	unpaid
1271	35	\N	\N	2024-09-27	2024-10-27	1400000	unpaid
1272	35	\N	\N	2024-10-27	2024-11-27	1400000	unpaid
1273	35	\N	\N	2024-11-27	2024-12-27	1400000	unpaid
1274	35	\N	\N	2024-12-27	2025-01-27	1400000	unpaid
1275	35	\N	\N	2025-01-27	2025-02-27	1400000	unpaid
1276	35	\N	\N	2025-02-27	2025-03-27	1400000	unpaid
1277	35	\N	\N	2025-03-27	2025-04-27	1400000	unpaid
1278	35	\N	\N	2025-04-27	2025-05-27	1400000	unpaid
1279	35	\N	\N	2025-05-27	2025-06-27	1400000	unpaid
1280	35	\N	\N	2025-06-27	2025-07-27	1400000	unpaid
1281	35	\N	\N	2025-07-27	2025-08-27	1400000	unpaid
1282	35	\N	\N	2025-08-27	2025-09-27	1400000	unpaid
1283	35	\N	\N	2025-09-27	2025-10-27	1400000	unpaid
1284	35	\N	\N	2025-10-27	2025-11-27	1400000	unpaid
1290	36	\N	\N	2023-02-28	2023-03-28	9800000	unpaid
1291	36	\N	\N	2023-03-28	2023-04-28	9800000	unpaid
1292	36	\N	\N	2023-04-28	2023-05-28	9800000	unpaid
1293	36	\N	\N	2023-05-28	2023-06-28	9800000	unpaid
1294	36	\N	\N	2023-06-28	2023-07-28	9800000	unpaid
1295	36	\N	\N	2023-07-28	2023-08-28	9800000	unpaid
1296	36	\N	\N	2023-08-28	2023-09-28	9800000	unpaid
1297	36	\N	\N	2023-09-28	2023-10-28	9800000	unpaid
1298	36	\N	\N	2023-10-28	2023-11-28	9800000	unpaid
1299	36	\N	\N	2023-11-28	2023-12-28	9800000	unpaid
1300	36	\N	\N	2023-12-28	2024-01-28	9800000	unpaid
1301	36	\N	\N	2024-01-28	2024-02-28	9800000	unpaid
1302	36	\N	\N	2024-02-28	2024-03-28	9800000	unpaid
1303	36	\N	\N	2024-03-28	2024-04-28	9800000	unpaid
1304	36	\N	\N	2024-04-28	2024-05-28	9800000	unpaid
1305	36	\N	\N	2024-05-28	2024-06-28	9800000	unpaid
1306	36	\N	\N	2024-06-28	2024-07-28	9800000	unpaid
1307	36	\N	\N	2024-07-28	2024-08-28	9800000	unpaid
1308	36	\N	\N	2024-08-28	2024-09-28	9800000	unpaid
1309	36	\N	\N	2024-09-28	2024-10-28	9800000	unpaid
1310	36	\N	\N	2024-10-28	2024-11-28	9800000	unpaid
1311	36	\N	\N	2024-11-28	2024-12-28	9800000	unpaid
1312	36	\N	\N	2024-12-28	2025-01-28	9800000	unpaid
1313	36	\N	\N	2025-01-28	2025-02-28	9800000	unpaid
1314	36	\N	\N	2025-02-28	2025-03-28	9800000	unpaid
1315	36	\N	\N	2025-03-28	2025-04-28	9800000	unpaid
1316	36	\N	\N	2025-04-28	2025-05-28	9800000	unpaid
1317	36	\N	\N	2025-05-28	2025-06-28	9800000	unpaid
1318	36	\N	\N	2025-06-28	2025-07-28	9800000	unpaid
1319	36	\N	\N	2025-07-28	2025-08-28	9800000	unpaid
1320	36	\N	\N	2025-08-28	2025-09-28	9800000	unpaid
1321	36	\N	\N	2025-09-28	2025-10-28	9800000	unpaid
1322	36	\N	\N	2025-10-28	2025-11-28	9800000	unpaid
1323	36	\N	\N	2025-11-28	2025-12-28	9800000	unpaid
1324	36	\N	\N	2025-12-28	2026-01-28	9800000	unpaid
1325	36	\N	\N	2026-01-28	2026-02-28	9800000	unpaid
1326	36	\N	\N	2026-02-28	2026-03-28	9800000	unpaid
1327	36	\N	\N	2026-03-28	2026-04-28	9800000	unpaid
1328	36	\N	\N	2026-04-28	2026-05-28	9800000	unpaid
1329	36	\N	\N	2026-05-28	2026-06-28	9800000	unpaid
1330	36	\N	\N	2026-06-28	2026-07-28	9800000	unpaid
1331	36	\N	\N	2026-07-28	2026-08-28	9800000	unpaid
1332	36	\N	\N	2026-08-28	2026-09-28	9800000	unpaid
1333	36	\N	\N	2026-09-28	2026-10-28	9800000	unpaid
1334	36	\N	\N	2026-10-28	2026-11-28	9800000	unpaid
1335	36	\N	\N	2026-11-28	2026-12-28	9800000	unpaid
1336	36	\N	\N	2026-12-28	2027-01-28	9800000	unpaid
1337	36	\N	\N	2027-01-28	2027-02-28	9800000	unpaid
1338	36	\N	\N	2027-02-28	2027-03-28	9800000	unpaid
1339	36	\N	\N	2027-03-28	2027-04-28	9800000	unpaid
1340	36	\N	\N	2027-04-28	2027-05-28	9800000	unpaid
1341	36	\N	\N	2027-05-28	2027-06-28	9800000	unpaid
1342	36	\N	\N	2027-06-28	2027-07-28	9800000	unpaid
1343	36	\N	\N	2027-07-28	2027-08-28	9800000	unpaid
1344	36	\N	\N	2027-08-28	2027-09-28	9800000	unpaid
1348	37	\N	\N	2023-02-13	2023-03-13	5200000	unpaid
1349	37	\N	\N	2023-03-13	2023-04-13	5200000	unpaid
1350	37	\N	\N	2023-04-13	2023-05-13	5200000	unpaid
1351	37	\N	\N	2023-05-13	2023-06-13	5200000	unpaid
1352	37	\N	\N	2023-06-13	2023-07-13	5200000	unpaid
1353	37	\N	\N	2023-07-13	2023-08-13	5200000	unpaid
1354	37	\N	\N	2023-08-13	2023-09-13	5200000	unpaid
1355	37	\N	\N	2023-09-13	2023-10-13	5200000	unpaid
1356	37	\N	\N	2023-10-13	2023-11-13	5200000	unpaid
1357	37	\N	\N	2023-11-13	2023-12-13	5200000	unpaid
1358	37	\N	\N	2023-12-13	2024-01-13	5200000	unpaid
1359	37	\N	\N	2024-01-13	2024-02-13	5200000	unpaid
1360	37	\N	\N	2024-02-13	2024-03-13	5200000	unpaid
130	4	2020-12-08	cash	2020-12-15	2021-01-15	9600000	paid
131	4	2021-01-08	cash	2021-01-15	2021-02-15	9600000	paid
132	4	2021-02-08	cash	2021-02-15	2021-03-15	9600000	paid
133	4	2021-03-08	cash	2021-03-15	2021-04-15	9600000	paid
134	4	2021-04-08	cash	2021-04-15	2021-05-15	9600000	paid
1361	37	\N	\N	2024-03-13	2024-04-13	5200000	unpaid
1362	37	\N	\N	2024-04-13	2024-05-13	5200000	unpaid
1363	37	\N	\N	2024-05-13	2024-06-13	5200000	unpaid
1364	37	\N	\N	2024-06-13	2024-07-13	5200000	unpaid
1365	37	\N	\N	2024-07-13	2024-08-13	5200000	unpaid
1366	37	\N	\N	2024-08-13	2024-09-13	5200000	unpaid
1367	37	\N	\N	2024-09-13	2024-10-13	5200000	unpaid
1368	37	\N	\N	2024-10-13	2024-11-13	5200000	unpaid
1369	37	\N	\N	2024-11-13	2024-12-13	5200000	unpaid
1370	37	\N	\N	2024-12-13	2025-01-13	5200000	unpaid
1371	37	\N	\N	2025-01-13	2025-02-13	5200000	unpaid
1372	37	\N	\N	2025-02-13	2025-03-13	5200000	unpaid
1373	37	\N	\N	2025-03-13	2025-04-13	5200000	unpaid
1374	37	\N	\N	2025-04-13	2025-05-13	5200000	unpaid
1375	37	\N	\N	2025-05-13	2025-06-13	5200000	unpaid
1376	37	\N	\N	2025-06-13	2025-07-13	5200000	unpaid
1377	37	\N	\N	2025-07-13	2025-08-13	5200000	unpaid
1378	37	\N	\N	2025-08-13	2025-09-13	5200000	unpaid
1379	37	\N	\N	2025-09-13	2025-10-13	5200000	unpaid
1380	37	\N	\N	2025-10-13	2025-11-13	5200000	unpaid
1381	37	\N	\N	2025-11-13	2025-12-13	5200000	unpaid
1382	37	\N	\N	2025-12-13	2026-01-13	5200000	unpaid
1383	37	\N	\N	2026-01-13	2026-02-13	5200000	unpaid
1384	37	\N	\N	2026-02-13	2026-03-13	5200000	unpaid
1385	37	\N	\N	2026-03-13	2026-04-13	5200000	unpaid
1386	37	\N	\N	2026-04-13	2026-05-13	5200000	unpaid
1387	37	\N	\N	2026-05-13	2026-06-13	5200000	unpaid
1388	37	\N	\N	2026-06-13	2026-07-13	5200000	unpaid
1389	37	\N	\N	2026-07-13	2026-08-13	5200000	unpaid
1390	37	\N	\N	2026-08-13	2026-09-13	5200000	unpaid
1391	37	\N	\N	2026-09-13	2026-10-13	5200000	unpaid
1392	37	\N	\N	2026-10-13	2026-11-13	5200000	unpaid
1400	38	\N	\N	2023-02-07	2023-03-07	3600000	unpaid
1401	38	\N	\N	2023-03-07	2023-04-07	3600000	unpaid
1402	38	\N	\N	2023-04-07	2023-05-07	3600000	unpaid
1403	38	\N	\N	2023-05-07	2023-06-07	3600000	unpaid
1404	38	\N	\N	2023-06-07	2023-07-07	3600000	unpaid
1405	38	\N	\N	2023-07-07	2023-08-07	3600000	unpaid
1406	38	\N	\N	2023-08-07	2023-09-07	3600000	unpaid
1407	38	\N	\N	2023-09-07	2023-10-07	3600000	unpaid
1408	38	\N	\N	2023-10-07	2023-11-07	3600000	unpaid
1409	38	\N	\N	2023-11-07	2023-12-07	3600000	unpaid
1410	38	\N	\N	2023-12-07	2024-01-07	3600000	unpaid
1411	38	\N	\N	2024-01-07	2024-02-07	3600000	unpaid
1412	38	\N	\N	2024-02-07	2024-03-07	3600000	unpaid
1413	38	\N	\N	2024-03-07	2024-04-07	3600000	unpaid
1414	38	\N	\N	2024-04-07	2024-05-07	3600000	unpaid
1415	38	\N	\N	2024-05-07	2024-06-07	3600000	unpaid
1416	38	\N	\N	2024-06-07	2024-07-07	3600000	unpaid
1417	38	\N	\N	2024-07-07	2024-08-07	3600000	unpaid
1418	38	\N	\N	2024-08-07	2024-09-07	3600000	unpaid
1419	38	\N	\N	2024-09-07	2024-10-07	3600000	unpaid
1420	38	\N	\N	2024-10-07	2024-11-07	3600000	unpaid
1421	38	\N	\N	2024-11-07	2024-12-07	3600000	unpaid
1422	38	\N	\N	2024-12-07	2025-01-07	3600000	unpaid
1423	38	\N	\N	2025-01-07	2025-02-07	3600000	unpaid
1424	38	\N	\N	2025-02-07	2025-03-07	3600000	unpaid
1425	38	\N	\N	2025-03-07	2025-04-07	3600000	unpaid
1426	38	\N	\N	2025-04-07	2025-05-07	3600000	unpaid
1427	38	\N	\N	2025-05-07	2025-06-07	3600000	unpaid
1428	38	\N	\N	2025-06-07	2025-07-07	3600000	unpaid
1439	39	\N	\N	2023-02-11	2023-03-11	9700000	unpaid
1440	39	\N	\N	2023-03-11	2023-04-11	9700000	unpaid
1441	39	\N	\N	2023-04-11	2023-05-11	9700000	unpaid
1442	39	\N	\N	2023-05-11	2023-06-11	9700000	unpaid
1443	39	\N	\N	2023-06-11	2023-07-11	9700000	unpaid
1444	39	\N	\N	2023-07-11	2023-08-11	9700000	unpaid
1445	39	\N	\N	2023-08-11	2023-09-11	9700000	unpaid
1446	39	\N	\N	2023-09-11	2023-10-11	9700000	unpaid
1447	39	\N	\N	2023-10-11	2023-11-11	9700000	unpaid
1448	39	\N	\N	2023-11-11	2023-12-11	9700000	unpaid
1449	39	\N	\N	2023-12-11	2024-01-11	9700000	unpaid
1450	39	\N	\N	2024-01-11	2024-02-11	9700000	unpaid
1451	39	\N	\N	2024-02-11	2024-03-11	9700000	unpaid
1452	39	\N	\N	2024-03-11	2024-04-11	9700000	unpaid
1453	39	\N	\N	2024-04-11	2024-05-11	9700000	unpaid
1454	39	\N	\N	2024-05-11	2024-06-11	9700000	unpaid
1455	39	\N	\N	2024-06-11	2024-07-11	9700000	unpaid
1456	39	\N	\N	2024-07-11	2024-08-11	9700000	unpaid
1457	39	\N	\N	2024-08-11	2024-09-11	9700000	unpaid
1458	39	\N	\N	2024-09-11	2024-10-11	9700000	unpaid
1459	39	\N	\N	2024-10-11	2024-11-11	9700000	unpaid
1460	39	\N	\N	2024-11-11	2024-12-11	9700000	unpaid
1461	39	\N	\N	2024-12-11	2025-01-11	9700000	unpaid
1462	39	\N	\N	2025-01-11	2025-02-11	9700000	unpaid
1463	39	\N	\N	2025-02-11	2025-03-11	9700000	unpaid
1464	39	\N	\N	2025-03-11	2025-04-11	9700000	unpaid
1465	39	\N	\N	2025-04-11	2025-05-11	9700000	unpaid
1466	39	\N	\N	2025-05-11	2025-06-11	9700000	unpaid
1467	39	\N	\N	2025-06-11	2025-07-11	9700000	unpaid
1468	39	\N	\N	2025-07-11	2025-08-11	9700000	unpaid
1469	39	\N	\N	2025-08-11	2025-09-11	9700000	unpaid
1470	39	\N	\N	2025-09-11	2025-10-11	9700000	unpaid
1471	39	\N	\N	2025-10-11	2025-11-11	9700000	unpaid
1472	39	\N	\N	2025-11-11	2025-12-11	9700000	unpaid
1473	39	\N	\N	2025-12-11	2026-01-11	9700000	unpaid
1474	39	\N	\N	2026-01-11	2026-02-11	9700000	unpaid
1475	39	\N	\N	2026-02-11	2026-03-11	9700000	unpaid
1476	39	\N	\N	2026-03-11	2026-04-11	9700000	unpaid
1477	39	\N	\N	2026-04-11	2026-05-11	9700000	unpaid
1478	39	\N	\N	2026-05-11	2026-06-11	9700000	unpaid
1479	39	\N	\N	2026-06-11	2026-07-11	9700000	unpaid
1480	39	\N	\N	2026-07-11	2026-08-11	9700000	unpaid
1481	39	\N	\N	2026-08-11	2026-09-11	9700000	unpaid
1482	39	\N	\N	2026-09-11	2026-10-11	9700000	unpaid
1483	39	\N	\N	2026-10-11	2026-11-11	9700000	unpaid
1484	39	\N	\N	2026-11-11	2026-12-11	9700000	unpaid
1485	39	\N	\N	2026-12-11	2027-01-11	9700000	unpaid
1486	39	\N	\N	2027-01-11	2027-02-11	9700000	unpaid
1487	39	\N	\N	2027-02-11	2027-03-11	9700000	unpaid
1488	39	\N	\N	2027-03-11	2027-04-11	9700000	unpaid
135	4	2021-05-08	cash	2021-05-15	2021-06-15	9600000	paid
136	4	2021-06-08	cash	2021-06-15	2021-07-15	9600000	paid
137	4	2021-07-08	cash	2021-07-15	2021-08-15	9600000	paid
1559	42	\N	\N	2023-02-06	2023-03-06	6500000	unpaid
1560	42	\N	\N	2023-03-06	2023-04-06	6500000	unpaid
1580	43	\N	\N	2023-02-13	2023-03-13	1400000	unpaid
1581	43	\N	\N	2023-03-13	2023-04-13	1400000	unpaid
1582	43	\N	\N	2023-04-13	2023-05-13	1400000	unpaid
1583	43	\N	\N	2023-05-13	2023-06-13	1400000	unpaid
1584	43	\N	\N	2023-06-13	2023-07-13	1400000	unpaid
1585	43	\N	\N	2023-07-13	2023-08-13	1400000	unpaid
1586	43	\N	\N	2023-08-13	2023-09-13	1400000	unpaid
1587	43	\N	\N	2023-09-13	2023-10-13	1400000	unpaid
1588	43	\N	\N	2023-10-13	2023-11-13	1400000	unpaid
1589	43	\N	\N	2023-11-13	2023-12-13	1400000	unpaid
1590	43	\N	\N	2023-12-13	2024-01-13	1400000	unpaid
1591	43	\N	\N	2024-01-13	2024-02-13	1400000	unpaid
1592	43	\N	\N	2024-02-13	2024-03-13	1400000	unpaid
1593	43	\N	\N	2024-03-13	2024-04-13	1400000	unpaid
1594	43	\N	\N	2024-04-13	2024-05-13	1400000	unpaid
1595	43	\N	\N	2024-05-13	2024-06-13	1400000	unpaid
1596	43	\N	\N	2024-06-13	2024-07-13	1400000	unpaid
1597	43	\N	\N	2024-07-13	2024-08-13	1400000	unpaid
1598	43	\N	\N	2024-08-13	2024-09-13	1400000	unpaid
1599	43	\N	\N	2024-09-13	2024-10-13	1400000	unpaid
1600	43	\N	\N	2024-10-13	2024-11-13	1400000	unpaid
1601	43	\N	\N	2024-11-13	2024-12-13	1400000	unpaid
1602	43	\N	\N	2024-12-13	2025-01-13	1400000	unpaid
1603	43	\N	\N	2025-01-13	2025-02-13	1400000	unpaid
1604	43	\N	\N	2025-02-13	2025-03-13	1400000	unpaid
1605	43	\N	\N	2025-03-13	2025-04-13	1400000	unpaid
1606	43	\N	\N	2025-04-13	2025-05-13	1400000	unpaid
1607	43	\N	\N	2025-05-13	2025-06-13	1400000	unpaid
1608	43	\N	\N	2025-06-13	2025-07-13	1400000	unpaid
138	4	2021-08-08	cash	2021-08-15	2021-09-15	9600000	paid
139	4	2021-09-08	cash	2021-09-15	2021-10-15	9600000	paid
140	4	2021-10-08	cash	2021-10-15	2021-11-15	9600000	paid
1656	44	\N	\N	2023-02-05	2023-03-05	3200000	unpaid
1657	44	\N	\N	2023-03-05	2023-04-05	3200000	unpaid
1658	44	\N	\N	2023-04-05	2023-05-05	3200000	unpaid
1659	44	\N	\N	2023-05-05	2023-06-05	3200000	unpaid
1660	44	\N	\N	2023-06-05	2023-07-05	3200000	unpaid
1661	44	\N	\N	2023-07-05	2023-08-05	3200000	unpaid
1662	44	\N	\N	2023-08-05	2023-09-05	3200000	unpaid
1663	44	\N	\N	2023-09-05	2023-10-05	3200000	unpaid
1664	44	\N	\N	2023-10-05	2023-11-05	3200000	unpaid
1665	44	\N	\N	2023-11-05	2023-12-05	3200000	unpaid
1666	44	\N	\N	2023-12-05	2024-01-05	3200000	unpaid
1667	44	\N	\N	2024-01-05	2024-02-05	3200000	unpaid
1668	44	\N	\N	2024-02-05	2024-03-05	3200000	unpaid
1705	45	\N	\N	2023-02-19	2023-03-19	7300000	unpaid
1706	45	\N	\N	2023-03-19	2023-04-19	7300000	unpaid
1707	45	\N	\N	2023-04-19	2023-05-19	7300000	unpaid
1708	45	\N	\N	2023-05-19	2023-06-19	7300000	unpaid
1709	45	\N	\N	2023-06-19	2023-07-19	7300000	unpaid
1710	45	\N	\N	2023-07-19	2023-08-19	7300000	unpaid
1711	45	\N	\N	2023-08-19	2023-09-19	7300000	unpaid
1712	45	\N	\N	2023-09-19	2023-10-19	7300000	unpaid
1713	45	\N	\N	2023-10-19	2023-11-19	7300000	unpaid
1714	45	\N	\N	2023-11-19	2023-12-19	7300000	unpaid
1715	45	\N	\N	2023-12-19	2024-01-19	7300000	unpaid
1716	45	\N	\N	2024-01-19	2024-02-19	7300000	unpaid
1717	45	\N	\N	2024-02-19	2024-03-19	7300000	unpaid
1718	45	\N	\N	2024-03-19	2024-04-19	7300000	unpaid
1719	45	\N	\N	2024-04-19	2024-05-19	7300000	unpaid
1720	45	\N	\N	2024-05-19	2024-06-19	7300000	unpaid
1721	45	\N	\N	2024-06-19	2024-07-19	7300000	unpaid
1722	45	\N	\N	2024-07-19	2024-08-19	7300000	unpaid
1723	45	\N	\N	2024-08-19	2024-09-19	7300000	unpaid
1724	45	\N	\N	2024-09-19	2024-10-19	7300000	unpaid
1725	45	\N	\N	2024-10-19	2024-11-19	7300000	unpaid
1726	45	\N	\N	2024-11-19	2024-12-19	7300000	unpaid
1727	45	\N	\N	2024-12-19	2025-01-19	7300000	unpaid
1728	45	\N	\N	2025-01-19	2025-02-19	7300000	unpaid
1767	46	\N	\N	2023-02-14	2023-03-14	8000000	unpaid
1768	46	\N	\N	2023-03-14	2023-04-14	8000000	unpaid
141	4	2021-11-08	cash	2021-11-15	2021-12-15	9600000	paid
142	4	2021-12-08	cash	2021-12-15	2022-01-15	9600000	paid
143	4	2022-01-08	cash	2022-01-15	2022-02-15	9600000	paid
144	4	2022-02-08	cash	2022-02-15	2022-03-15	9600000	paid
145	4	2022-03-08	cash	2022-03-15	2022-04-15	9600000	paid
1769	46	\N	\N	2023-04-14	2023-05-14	8000000	unpaid
1770	46	\N	\N	2023-05-14	2023-06-14	8000000	unpaid
1771	46	\N	\N	2023-06-14	2023-07-14	8000000	unpaid
1772	46	\N	\N	2023-07-14	2023-08-14	8000000	unpaid
1773	46	\N	\N	2023-08-14	2023-09-14	8000000	unpaid
1774	46	\N	\N	2023-09-14	2023-10-14	8000000	unpaid
1775	46	\N	\N	2023-10-14	2023-11-14	8000000	unpaid
1776	46	\N	\N	2023-11-14	2023-12-14	8000000	unpaid
1777	46	\N	\N	2023-12-14	2024-01-14	8000000	unpaid
1778	46	\N	\N	2024-01-14	2024-02-14	8000000	unpaid
1779	46	\N	\N	2024-02-14	2024-03-14	8000000	unpaid
1780	46	\N	\N	2024-03-14	2024-04-14	8000000	unpaid
1781	46	\N	\N	2024-04-14	2024-05-14	8000000	unpaid
1782	46	\N	\N	2024-05-14	2024-06-14	8000000	unpaid
1783	46	\N	\N	2024-06-14	2024-07-14	8000000	unpaid
1784	46	\N	\N	2024-07-14	2024-08-14	8000000	unpaid
1785	46	\N	\N	2024-08-14	2024-09-14	8000000	unpaid
1786	46	\N	\N	2024-09-14	2024-10-14	8000000	unpaid
1787	46	\N	\N	2024-10-14	2024-11-14	8000000	unpaid
1788	46	\N	\N	2024-11-14	2024-12-14	8000000	unpaid
1827	47	\N	\N	2023-02-15	2023-03-15	4200000	unpaid
1828	47	\N	\N	2023-03-15	2023-04-15	4200000	unpaid
1829	47	\N	\N	2023-04-15	2023-05-15	4200000	unpaid
1830	47	\N	\N	2023-05-15	2023-06-15	4200000	unpaid
1831	47	\N	\N	2023-06-15	2023-07-15	4200000	unpaid
1832	47	\N	\N	2023-07-15	2023-08-15	4200000	unpaid
1833	47	\N	\N	2023-08-15	2023-09-15	4200000	unpaid
1834	47	\N	\N	2023-09-15	2023-10-15	4200000	unpaid
1835	47	\N	\N	2023-10-15	2023-11-15	4200000	unpaid
1836	47	\N	\N	2023-11-15	2023-12-15	4200000	unpaid
1875	49	\N	\N	2023-02-16	2023-03-16	6600000	unpaid
1876	49	\N	\N	2023-03-16	2023-04-16	6600000	unpaid
1877	49	\N	\N	2023-04-16	2023-05-16	6600000	unpaid
1878	49	\N	\N	2023-05-16	2023-06-16	6600000	unpaid
1879	49	\N	\N	2023-06-16	2023-07-16	6600000	unpaid
1880	49	\N	\N	2023-07-16	2023-08-16	6600000	unpaid
1881	49	\N	\N	2023-08-16	2023-09-16	6600000	unpaid
1882	49	\N	\N	2023-09-16	2023-10-16	6600000	unpaid
1883	49	\N	\N	2023-10-16	2023-11-16	6600000	unpaid
1884	49	\N	\N	2023-11-16	2023-12-16	6600000	unpaid
1885	49	\N	\N	2023-12-16	2024-01-16	6600000	unpaid
1886	49	\N	\N	2024-01-16	2024-02-16	6600000	unpaid
1887	49	\N	\N	2024-02-16	2024-03-16	6600000	unpaid
1888	49	\N	\N	2024-03-16	2024-04-16	6600000	unpaid
1889	49	\N	\N	2024-04-16	2024-05-16	6600000	unpaid
1890	49	\N	\N	2024-05-16	2024-06-16	6600000	unpaid
1891	49	\N	\N	2024-06-16	2024-07-16	6600000	unpaid
1892	49	\N	\N	2024-07-16	2024-08-16	6600000	unpaid
1893	49	\N	\N	2024-08-16	2024-09-16	6600000	unpaid
1894	49	\N	\N	2024-09-16	2024-10-16	6600000	unpaid
1895	49	\N	\N	2024-10-16	2024-11-16	6600000	unpaid
1896	49	\N	\N	2024-11-16	2024-12-16	6600000	unpaid
1897	49	\N	\N	2024-12-16	2025-01-16	6600000	unpaid
1898	49	\N	\N	2025-01-16	2025-02-16	6600000	unpaid
1899	49	\N	\N	2025-02-16	2025-03-16	6600000	unpaid
1900	49	\N	\N	2025-03-16	2025-04-16	6600000	unpaid
1901	49	\N	\N	2025-04-16	2025-05-16	6600000	unpaid
1902	49	\N	\N	2025-05-16	2025-06-16	6600000	unpaid
1903	49	\N	\N	2025-06-16	2025-07-16	6600000	unpaid
1904	49	\N	\N	2025-07-16	2025-08-16	6600000	unpaid
146	4	2022-04-08	cash	2022-04-15	2022-05-15	9600000	paid
147	4	2022-05-08	cash	2022-05-15	2022-06-15	9600000	paid
148	4	2022-06-08	cash	2022-06-15	2022-07-15	9600000	paid
1905	49	\N	\N	2025-08-16	2025-09-16	6600000	unpaid
1906	49	\N	\N	2025-09-16	2025-10-16	6600000	unpaid
1907	49	\N	\N	2025-10-16	2025-11-16	6600000	unpaid
1908	49	\N	\N	2025-11-16	2025-12-16	6600000	unpaid
2002	53	\N	\N	2023-02-04	2023-03-04	5300000	unpaid
2003	53	\N	\N	2023-03-04	2023-04-04	5300000	unpaid
2004	53	\N	\N	2023-04-04	2023-05-04	5300000	unpaid
2005	53	\N	\N	2023-05-04	2023-06-04	5300000	unpaid
2006	53	\N	\N	2023-06-04	2023-07-04	5300000	unpaid
2007	53	\N	\N	2023-07-04	2023-08-04	5300000	unpaid
2008	53	\N	\N	2023-08-04	2023-09-04	5300000	unpaid
2009	53	\N	\N	2023-09-04	2023-10-04	5300000	unpaid
2010	53	\N	\N	2023-10-04	2023-11-04	5300000	unpaid
2011	53	\N	\N	2023-11-04	2023-12-04	5300000	unpaid
2012	53	\N	\N	2023-12-04	2024-01-04	5300000	unpaid
2013	53	\N	\N	2024-01-04	2024-02-04	5300000	unpaid
2014	53	\N	\N	2024-02-04	2024-03-04	5300000	unpaid
2015	53	\N	\N	2024-03-04	2024-04-04	5300000	unpaid
2016	53	\N	\N	2024-04-04	2024-05-04	5300000	unpaid
2017	53	\N	\N	2024-05-04	2024-06-04	5300000	unpaid
2018	53	\N	\N	2024-06-04	2024-07-04	5300000	unpaid
2019	53	\N	\N	2024-07-04	2024-08-04	5300000	unpaid
2020	53	\N	\N	2024-08-04	2024-09-04	5300000	unpaid
2021	53	\N	\N	2024-09-04	2024-10-04	5300000	unpaid
2022	53	\N	\N	2024-10-04	2024-11-04	5300000	unpaid
2023	53	\N	\N	2024-11-04	2024-12-04	5300000	unpaid
2024	53	\N	\N	2024-12-04	2025-01-04	5300000	unpaid
2025	53	\N	\N	2025-01-04	2025-02-04	5300000	unpaid
2026	53	\N	\N	2025-02-04	2025-03-04	5300000	unpaid
2027	53	\N	\N	2025-03-04	2025-04-04	5300000	unpaid
2028	53	\N	\N	2025-04-04	2025-05-04	5300000	unpaid
2029	53	\N	\N	2025-05-04	2025-06-04	5300000	unpaid
2030	53	\N	\N	2025-06-04	2025-07-04	5300000	unpaid
2031	53	\N	\N	2025-07-04	2025-08-04	5300000	unpaid
2032	53	\N	\N	2025-08-04	2025-09-04	5300000	unpaid
2033	53	\N	\N	2025-09-04	2025-10-04	5300000	unpaid
2034	53	\N	\N	2025-10-04	2025-11-04	5300000	unpaid
2035	53	\N	\N	2025-11-04	2025-12-04	5300000	unpaid
2036	53	\N	\N	2025-12-04	2026-01-04	5300000	unpaid
2037	53	\N	\N	2026-01-04	2026-02-04	5300000	unpaid
2038	53	\N	\N	2026-02-04	2026-03-04	5300000	unpaid
2039	53	\N	\N	2026-03-04	2026-04-04	5300000	unpaid
2040	53	\N	\N	2026-04-04	2026-05-04	5300000	unpaid
149	4	2022-07-08	cash	2022-07-15	2022-08-15	9600000	paid
2041	53	\N	\N	2026-05-04	2026-06-04	5300000	unpaid
2042	53	\N	\N	2026-06-04	2026-07-04	5300000	unpaid
2043	53	\N	\N	2026-07-04	2026-08-04	5300000	unpaid
2044	53	\N	\N	2026-08-04	2026-09-04	5300000	unpaid
2045	53	\N	\N	2026-09-04	2026-10-04	5300000	unpaid
2046	53	\N	\N	2026-10-04	2026-11-04	5300000	unpaid
2047	53	\N	\N	2026-11-04	2026-12-04	5300000	unpaid
2048	53	\N	\N	2026-12-04	2027-01-04	5300000	unpaid
2049	53	\N	\N	2027-01-04	2027-02-04	5300000	unpaid
2050	53	\N	\N	2027-02-04	2027-03-04	5300000	unpaid
2051	53	\N	\N	2027-03-04	2027-04-04	5300000	unpaid
2052	53	\N	\N	2027-04-04	2027-05-04	5300000	unpaid
2063	54	\N	\N	2023-02-19	2023-03-19	1400000	unpaid
2064	54	\N	\N	2023-03-19	2023-04-19	1400000	unpaid
2065	54	\N	\N	2023-04-19	2023-05-19	1400000	unpaid
2066	54	\N	\N	2023-05-19	2023-06-19	1400000	unpaid
2067	54	\N	\N	2023-06-19	2023-07-19	1400000	unpaid
2068	54	\N	\N	2023-07-19	2023-08-19	1400000	unpaid
2069	54	\N	\N	2023-08-19	2023-09-19	1400000	unpaid
2070	54	\N	\N	2023-09-19	2023-10-19	1400000	unpaid
2071	54	\N	\N	2023-10-19	2023-11-19	1400000	unpaid
2072	54	\N	\N	2023-11-19	2023-12-19	1400000	unpaid
2073	54	\N	\N	2023-12-19	2024-01-19	1400000	unpaid
2074	54	\N	\N	2024-01-19	2024-02-19	1400000	unpaid
2075	54	\N	\N	2024-02-19	2024-03-19	1400000	unpaid
2076	54	\N	\N	2024-03-19	2024-04-19	1400000	unpaid
2110	55	\N	\N	2023-02-12	2023-03-12	7500000	unpaid
2111	55	\N	\N	2023-03-12	2023-04-12	7500000	unpaid
2112	55	\N	\N	2023-04-12	2023-05-12	7500000	unpaid
2113	55	\N	\N	2023-05-12	2023-06-12	7500000	unpaid
2114	55	\N	\N	2023-06-12	2023-07-12	7500000	unpaid
2115	55	\N	\N	2023-07-12	2023-08-12	7500000	unpaid
2116	55	\N	\N	2023-08-12	2023-09-12	7500000	unpaid
2117	55	\N	\N	2023-09-12	2023-10-12	7500000	unpaid
2118	55	\N	\N	2023-10-12	2023-11-12	7500000	unpaid
2119	55	\N	\N	2023-11-12	2023-12-12	7500000	unpaid
2120	55	\N	\N	2023-12-12	2024-01-12	7500000	unpaid
2121	55	\N	\N	2024-01-12	2024-02-12	7500000	unpaid
2122	55	\N	\N	2024-02-12	2024-03-12	7500000	unpaid
2123	55	\N	\N	2024-03-12	2024-04-12	7500000	unpaid
2124	55	\N	\N	2024-04-12	2024-05-12	7500000	unpaid
2125	55	\N	\N	2024-05-12	2024-06-12	7500000	unpaid
2126	55	\N	\N	2024-06-12	2024-07-12	7500000	unpaid
2127	55	\N	\N	2024-07-12	2024-08-12	7500000	unpaid
2128	55	\N	\N	2024-08-12	2024-09-12	7500000	unpaid
2129	55	\N	\N	2024-09-12	2024-10-12	7500000	unpaid
2130	55	\N	\N	2024-10-12	2024-11-12	7500000	unpaid
2131	55	\N	\N	2024-11-12	2024-12-12	7500000	unpaid
2132	55	\N	\N	2024-12-12	2025-01-12	7500000	unpaid
2133	55	\N	\N	2025-01-12	2025-02-12	7500000	unpaid
2134	55	\N	\N	2025-02-12	2025-03-12	7500000	unpaid
2135	55	\N	\N	2025-03-12	2025-04-12	7500000	unpaid
2136	55	\N	\N	2025-04-12	2025-05-12	7500000	unpaid
2162	56	\N	\N	2023-02-28	2023-03-28	3500000	unpaid
2163	56	\N	\N	2023-03-28	2023-04-28	3500000	unpaid
2164	56	\N	\N	2023-04-28	2023-05-28	3500000	unpaid
2165	56	\N	\N	2023-05-28	2023-06-28	3500000	unpaid
2166	56	\N	\N	2023-06-28	2023-07-28	3500000	unpaid
2167	56	\N	\N	2023-07-28	2023-08-28	3500000	unpaid
2168	56	\N	\N	2023-08-28	2023-09-28	3500000	unpaid
2169	56	\N	\N	2023-09-28	2023-10-28	3500000	unpaid
2170	56	\N	\N	2023-10-28	2023-11-28	3500000	unpaid
2171	56	\N	\N	2023-11-28	2023-12-28	3500000	unpaid
2172	56	\N	\N	2023-12-28	2024-01-28	3500000	unpaid
150	4	2022-08-08	cash	2022-08-15	2022-09-15	9600000	paid
151	4	2022-09-08	cash	2022-09-15	2022-10-15	9600000	paid
152	4	2022-10-08	cash	2022-10-15	2022-11-15	9600000	paid
153	4	2022-11-08	cash	2022-11-15	2022-12-15	9600000	paid
154	4	2022-12-08	cash	2022-12-15	2023-01-15	9600000	paid
2191	57	\N	\N	2023-02-18	2023-03-18	1400000	unpaid
2192	57	\N	\N	2023-03-18	2023-04-18	1400000	unpaid
2193	57	\N	\N	2023-04-18	2023-05-18	1400000	unpaid
2194	57	\N	\N	2023-05-18	2023-06-18	1400000	unpaid
2195	57	\N	\N	2023-06-18	2023-07-18	1400000	unpaid
2196	57	\N	\N	2023-07-18	2023-08-18	1400000	unpaid
2197	57	\N	\N	2023-08-18	2023-09-18	1400000	unpaid
2198	57	\N	\N	2023-09-18	2023-10-18	1400000	unpaid
2199	57	\N	\N	2023-10-18	2023-11-18	1400000	unpaid
2200	57	\N	\N	2023-11-18	2023-12-18	1400000	unpaid
2201	57	\N	\N	2023-12-18	2024-01-18	1400000	unpaid
2202	57	\N	\N	2024-01-18	2024-02-18	1400000	unpaid
2203	57	\N	\N	2024-02-18	2024-03-18	1400000	unpaid
2204	57	\N	\N	2024-03-18	2024-04-18	1400000	unpaid
2205	57	\N	\N	2024-04-18	2024-05-18	1400000	unpaid
2206	57	\N	\N	2024-05-18	2024-06-18	1400000	unpaid
2207	57	\N	\N	2024-06-18	2024-07-18	1400000	unpaid
2208	57	\N	\N	2024-07-18	2024-08-18	1400000	unpaid
2209	57	\N	\N	2024-08-18	2024-09-18	1400000	unpaid
2210	57	\N	\N	2024-09-18	2024-10-18	1400000	unpaid
2211	57	\N	\N	2024-10-18	2024-11-18	1400000	unpaid
2212	57	\N	\N	2024-11-18	2024-12-18	1400000	unpaid
2213	57	\N	\N	2024-12-18	2025-01-18	1400000	unpaid
2214	57	\N	\N	2025-01-18	2025-02-18	1400000	unpaid
2215	57	\N	\N	2025-02-18	2025-03-18	1400000	unpaid
2216	57	\N	\N	2025-03-18	2025-04-18	1400000	unpaid
2217	57	\N	\N	2025-04-18	2025-05-18	1400000	unpaid
2218	57	\N	\N	2025-05-18	2025-06-18	1400000	unpaid
2219	57	\N	\N	2025-06-18	2025-07-18	1400000	unpaid
2220	57	\N	\N	2025-07-18	2025-08-18	1400000	unpaid
2254	58	\N	\N	2023-02-18	2023-03-18	9600000	unpaid
2255	58	\N	\N	2023-03-18	2023-04-18	9600000	unpaid
2256	58	\N	\N	2023-04-18	2023-05-18	9600000	unpaid
2257	58	\N	\N	2023-05-18	2023-06-18	9600000	unpaid
2258	58	\N	\N	2023-06-18	2023-07-18	9600000	unpaid
2259	58	\N	\N	2023-07-18	2023-08-18	9600000	unpaid
2260	58	\N	\N	2023-08-18	2023-09-18	9600000	unpaid
2261	58	\N	\N	2023-09-18	2023-10-18	9600000	unpaid
2262	58	\N	\N	2023-10-18	2023-11-18	9600000	unpaid
2263	58	\N	\N	2023-11-18	2023-12-18	9600000	unpaid
2264	58	\N	\N	2023-12-18	2024-01-18	9600000	unpaid
2265	58	\N	\N	2024-01-18	2024-02-18	9600000	unpaid
2266	58	\N	\N	2024-02-18	2024-03-18	9600000	unpaid
2267	58	\N	\N	2024-03-18	2024-04-18	9600000	unpaid
2268	58	\N	\N	2024-04-18	2024-05-18	9600000	unpaid
155	4	2023-01-08	cash	2023-01-15	2023-02-15	9600000	paid
163	5	2022-12-05	cash	2022-12-12	2023-01-12	700000	paid
164	5	2023-01-05	cash	2023-01-12	2023-02-12	700000	paid
2352	61	\N	\N	2023-02-04	2023-03-04	7900000	unpaid
2353	61	\N	\N	2023-03-04	2023-04-04	7900000	unpaid
2354	61	\N	\N	2023-04-04	2023-05-04	7900000	unpaid
2355	61	\N	\N	2023-05-04	2023-06-04	7900000	unpaid
2356	61	\N	\N	2023-06-04	2023-07-04	7900000	unpaid
2357	61	\N	\N	2023-07-04	2023-08-04	7900000	unpaid
2358	61	\N	\N	2023-08-04	2023-09-04	7900000	unpaid
2359	61	\N	\N	2023-09-04	2023-10-04	7900000	unpaid
2360	61	\N	\N	2023-10-04	2023-11-04	7900000	unpaid
2361	61	\N	\N	2023-11-04	2023-12-04	7900000	unpaid
2362	61	\N	\N	2023-12-04	2024-01-04	7900000	unpaid
2363	61	\N	\N	2024-01-04	2024-02-04	7900000	unpaid
2364	61	\N	\N	2024-02-04	2024-03-04	7900000	unpaid
2402	62	\N	\N	2023-02-23	2023-03-23	4800000	unpaid
2403	62	\N	\N	2023-03-23	2023-04-23	4800000	unpaid
2404	62	\N	\N	2023-04-23	2023-05-23	4800000	unpaid
2405	62	\N	\N	2023-05-23	2023-06-23	4800000	unpaid
2406	62	\N	\N	2023-06-23	2023-07-23	4800000	unpaid
2407	62	\N	\N	2023-07-23	2023-08-23	4800000	unpaid
2408	62	\N	\N	2023-08-23	2023-09-23	4800000	unpaid
2409	62	\N	\N	2023-09-23	2023-10-23	4800000	unpaid
2410	62	\N	\N	2023-10-23	2023-11-23	4800000	unpaid
2411	62	\N	\N	2023-11-23	2023-12-23	4800000	unpaid
2412	62	\N	\N	2023-12-23	2024-01-23	4800000	unpaid
2413	62	\N	\N	2024-01-23	2024-02-23	4800000	unpaid
2414	62	\N	\N	2024-02-23	2024-03-23	4800000	unpaid
2415	62	\N	\N	2024-03-23	2024-04-23	4800000	unpaid
2416	62	\N	\N	2024-04-23	2024-05-23	4800000	unpaid
2417	62	\N	\N	2024-05-23	2024-06-23	4800000	unpaid
2418	62	\N	\N	2024-06-23	2024-07-23	4800000	unpaid
2419	62	\N	\N	2024-07-23	2024-08-23	4800000	unpaid
2420	62	\N	\N	2024-08-23	2024-09-23	4800000	unpaid
2421	62	\N	\N	2024-09-23	2024-10-23	4800000	unpaid
2422	62	\N	\N	2024-10-23	2024-11-23	4800000	unpaid
2423	62	\N	\N	2024-11-23	2024-12-23	4800000	unpaid
2424	62	\N	\N	2024-12-23	2025-01-23	4800000	unpaid
171	6	2022-12-04	cash	2022-12-11	2023-01-11	3300000	paid
172	6	2023-01-04	cash	2023-01-11	2023-02-11	3300000	paid
248	7	2022-12-10	cash	2022-12-17	2023-01-17	5800000	paid
2485	65	\N	\N	2023-02-14	2023-03-14	9700000	unpaid
2486	65	\N	\N	2023-03-14	2023-04-14	9700000	unpaid
2487	65	\N	\N	2023-04-14	2023-05-14	9700000	unpaid
2488	65	\N	\N	2023-05-14	2023-06-14	9700000	unpaid
2489	65	\N	\N	2023-06-14	2023-07-14	9700000	unpaid
2490	65	\N	\N	2023-07-14	2023-08-14	9700000	unpaid
2491	65	\N	\N	2023-08-14	2023-09-14	9700000	unpaid
2492	65	\N	\N	2023-09-14	2023-10-14	9700000	unpaid
2493	65	\N	\N	2023-10-14	2023-11-14	9700000	unpaid
2494	65	\N	\N	2023-11-14	2023-12-14	9700000	unpaid
2495	65	\N	\N	2023-12-14	2024-01-14	9700000	unpaid
2496	65	\N	\N	2024-01-14	2024-02-14	9700000	unpaid
2569	70	\N	\N	2023-02-09	2023-03-09	2600000	unpaid
2570	70	\N	\N	2023-03-09	2023-04-09	2600000	unpaid
2571	70	\N	\N	2023-04-09	2023-05-09	2600000	unpaid
2572	70	\N	\N	2023-05-09	2023-06-09	2600000	unpaid
2573	70	\N	\N	2023-06-09	2023-07-09	2600000	unpaid
2574	70	\N	\N	2023-07-09	2023-08-09	2600000	unpaid
2575	70	\N	\N	2023-08-09	2023-09-09	2600000	unpaid
2576	70	\N	\N	2023-09-09	2023-10-09	2600000	unpaid
2577	70	\N	\N	2023-10-09	2023-11-09	2600000	unpaid
2578	70	\N	\N	2023-11-09	2023-12-09	2600000	unpaid
2579	70	\N	\N	2023-12-09	2024-01-09	2600000	unpaid
2580	70	\N	\N	2024-01-09	2024-02-09	2600000	unpaid
2581	70	\N	\N	2024-02-09	2024-03-09	2600000	unpaid
2582	70	\N	\N	2024-03-09	2024-04-09	2600000	unpaid
2583	70	\N	\N	2024-04-09	2024-05-09	2600000	unpaid
2584	70	\N	\N	2024-05-09	2024-06-09	2600000	unpaid
249	7	2023-01-10	cash	2023-01-17	2023-02-17	5800000	paid
2585	70	\N	\N	2024-06-09	2024-07-09	2600000	unpaid
2586	70	\N	\N	2024-07-09	2024-08-09	2600000	unpaid
2587	70	\N	\N	2024-08-09	2024-09-09	2600000	unpaid
2588	70	\N	\N	2024-09-09	2024-10-09	2600000	unpaid
2589	70	\N	\N	2024-10-09	2024-11-09	2600000	unpaid
2590	70	\N	\N	2024-11-09	2024-12-09	2600000	unpaid
2591	70	\N	\N	2024-12-09	2025-01-09	2600000	unpaid
2592	70	\N	\N	2025-01-09	2025-02-09	2600000	unpaid
2593	70	\N	\N	2025-02-09	2025-03-09	2600000	unpaid
2594	70	\N	\N	2025-03-09	2025-04-09	2600000	unpaid
2595	70	\N	\N	2025-04-09	2025-05-09	2600000	unpaid
2596	70	\N	\N	2025-05-09	2025-06-09	2600000	unpaid
2597	70	\N	\N	2025-06-09	2025-07-09	2600000	unpaid
2598	70	\N	\N	2025-07-09	2025-08-09	2600000	unpaid
2599	70	\N	\N	2025-08-09	2025-09-09	2600000	unpaid
2600	70	\N	\N	2025-09-09	2025-10-09	2600000	unpaid
2601	70	\N	\N	2025-10-09	2025-11-09	2600000	unpaid
2602	70	\N	\N	2025-11-09	2025-12-09	2600000	unpaid
2603	70	\N	\N	2025-12-09	2026-01-09	2600000	unpaid
2604	70	\N	\N	2026-01-09	2026-02-09	2600000	unpaid
2605	70	\N	\N	2026-02-09	2026-03-09	2600000	unpaid
2606	70	\N	\N	2026-03-09	2026-04-09	2600000	unpaid
2607	70	\N	\N	2026-04-09	2026-05-09	2600000	unpaid
2608	70	\N	\N	2026-05-09	2026-06-09	2600000	unpaid
2609	70	\N	\N	2026-06-09	2026-07-09	2600000	unpaid
2610	70	\N	\N	2026-07-09	2026-08-09	2600000	unpaid
2611	70	\N	\N	2026-08-09	2026-09-09	2600000	unpaid
2612	70	\N	\N	2026-09-09	2026-10-09	2600000	unpaid
2613	70	\N	\N	2026-10-09	2026-11-09	2600000	unpaid
2614	70	\N	\N	2026-11-09	2026-12-09	2600000	unpaid
2615	70	\N	\N	2026-12-09	2027-01-09	2600000	unpaid
2616	70	\N	\N	2027-01-09	2027-02-09	2600000	unpaid
2637	71	\N	\N	2023-02-07	2023-03-07	100000	unpaid
2638	71	\N	\N	2023-03-07	2023-04-07	100000	unpaid
2639	71	\N	\N	2023-04-07	2023-05-07	100000	unpaid
2640	71	\N	\N	2023-05-07	2023-06-07	100000	unpaid
2667	72	\N	\N	2023-02-28	2023-03-28	8900000	unpaid
2668	72	\N	\N	2023-03-28	2023-04-28	8900000	unpaid
2669	72	\N	\N	2023-04-28	2023-05-28	8900000	unpaid
2670	72	\N	\N	2023-05-28	2023-06-28	8900000	unpaid
2671	72	\N	\N	2023-06-28	2023-07-28	8900000	unpaid
2672	72	\N	\N	2023-07-28	2023-08-28	8900000	unpaid
2673	72	\N	\N	2023-08-28	2023-09-28	8900000	unpaid
2674	72	\N	\N	2023-09-28	2023-10-28	8900000	unpaid
2675	72	\N	\N	2023-10-28	2023-11-28	8900000	unpaid
2676	72	\N	\N	2023-11-28	2023-12-28	8900000	unpaid
2677	72	\N	\N	2023-12-28	2024-01-28	8900000	unpaid
2678	72	\N	\N	2024-01-28	2024-02-28	8900000	unpaid
2679	72	\N	\N	2024-02-28	2024-03-28	8900000	unpaid
2680	72	\N	\N	2024-03-28	2024-04-28	8900000	unpaid
2681	72	\N	\N	2024-04-28	2024-05-28	8900000	unpaid
2682	72	\N	\N	2024-05-28	2024-06-28	8900000	unpaid
2683	72	\N	\N	2024-06-28	2024-07-28	8900000	unpaid
2684	72	\N	\N	2024-07-28	2024-08-28	8900000	unpaid
2685	72	\N	\N	2024-08-28	2024-09-28	8900000	unpaid
2686	72	\N	\N	2024-09-28	2024-10-28	8900000	unpaid
2687	72	\N	\N	2024-10-28	2024-11-28	8900000	unpaid
2688	72	\N	\N	2024-11-28	2024-12-28	8900000	unpaid
2689	72	\N	\N	2024-12-28	2025-01-28	8900000	unpaid
2690	72	\N	\N	2025-01-28	2025-02-28	8900000	unpaid
2691	72	\N	\N	2025-02-28	2025-03-28	8900000	unpaid
2692	72	\N	\N	2025-03-28	2025-04-28	8900000	unpaid
2693	72	\N	\N	2025-04-28	2025-05-28	8900000	unpaid
2694	72	\N	\N	2025-05-28	2025-06-28	8900000	unpaid
2695	72	\N	\N	2025-06-28	2025-07-28	8900000	unpaid
2696	72	\N	\N	2025-07-28	2025-08-28	8900000	unpaid
2697	72	\N	\N	2025-08-28	2025-09-28	8900000	unpaid
2698	72	\N	\N	2025-09-28	2025-10-28	8900000	unpaid
2699	72	\N	\N	2025-10-28	2025-11-28	8900000	unpaid
2700	72	\N	\N	2025-11-28	2025-12-28	8900000	unpaid
157	5	2022-06-05	cash	2022-06-12	2022-07-12	700000	paid
158	5	2022-07-05	cash	2022-07-12	2022-08-12	700000	paid
159	5	2022-08-05	cash	2022-08-12	2022-09-12	700000	paid
2755	75	\N	\N	2023-02-11	2023-03-11	9100000	unpaid
2756	75	\N	\N	2023-03-11	2023-04-11	9100000	unpaid
2757	75	\N	\N	2023-04-11	2023-05-11	9100000	unpaid
2758	75	\N	\N	2023-05-11	2023-06-11	9100000	unpaid
2759	75	\N	\N	2023-06-11	2023-07-11	9100000	unpaid
2760	75	\N	\N	2023-07-11	2023-08-11	9100000	unpaid
2761	75	\N	\N	2023-08-11	2023-09-11	9100000	unpaid
2762	75	\N	\N	2023-09-11	2023-10-11	9100000	unpaid
2763	75	\N	\N	2023-10-11	2023-11-11	9100000	unpaid
2764	75	\N	\N	2023-11-11	2023-12-11	9100000	unpaid
2765	75	\N	\N	2023-12-11	2024-01-11	9100000	unpaid
2766	75	\N	\N	2024-01-11	2024-02-11	9100000	unpaid
2767	75	\N	\N	2024-02-11	2024-03-11	9100000	unpaid
2768	75	\N	\N	2024-03-11	2024-04-11	9100000	unpaid
2769	75	\N	\N	2024-04-11	2024-05-11	9100000	unpaid
2770	75	\N	\N	2024-05-11	2024-06-11	9100000	unpaid
2771	75	\N	\N	2024-06-11	2024-07-11	9100000	unpaid
2772	75	\N	\N	2024-07-11	2024-08-11	9100000	unpaid
2773	75	\N	\N	2024-08-11	2024-09-11	9100000	unpaid
2774	75	\N	\N	2024-09-11	2024-10-11	9100000	unpaid
2775	75	\N	\N	2024-10-11	2024-11-11	9100000	unpaid
2776	75	\N	\N	2024-11-11	2024-12-11	9100000	unpaid
2777	75	\N	\N	2024-12-11	2025-01-11	9100000	unpaid
2778	75	\N	\N	2025-01-11	2025-02-11	9100000	unpaid
2779	75	\N	\N	2025-02-11	2025-03-11	9100000	unpaid
2780	75	\N	\N	2025-03-11	2025-04-11	9100000	unpaid
2781	75	\N	\N	2025-04-11	2025-05-11	9100000	unpaid
2782	75	\N	\N	2025-05-11	2025-06-11	9100000	unpaid
2783	75	\N	\N	2025-06-11	2025-07-11	9100000	unpaid
2784	75	\N	\N	2025-07-11	2025-08-11	9100000	unpaid
2785	75	\N	\N	2025-08-11	2025-09-11	9100000	unpaid
2786	75	\N	\N	2025-09-11	2025-10-11	9100000	unpaid
2787	75	\N	\N	2025-10-11	2025-11-11	9100000	unpaid
2788	75	\N	\N	2025-11-11	2025-12-11	9100000	unpaid
2789	75	\N	\N	2025-12-11	2026-01-11	9100000	unpaid
2790	75	\N	\N	2026-01-11	2026-02-11	9100000	unpaid
2791	75	\N	\N	2026-02-11	2026-03-11	9100000	unpaid
2792	75	\N	\N	2026-03-11	2026-04-11	9100000	unpaid
2793	75	\N	\N	2026-04-11	2026-05-11	9100000	unpaid
2794	75	\N	\N	2026-05-11	2026-06-11	9100000	unpaid
2795	75	\N	\N	2026-06-11	2026-07-11	9100000	unpaid
2796	75	\N	\N	2026-07-11	2026-08-11	9100000	unpaid
160	5	2022-09-05	cash	2022-09-12	2022-10-12	700000	paid
2876	78	\N	\N	2023-02-20	2023-03-20	8200000	unpaid
2877	78	\N	\N	2023-03-20	2023-04-20	8200000	unpaid
2878	78	\N	\N	2023-04-20	2023-05-20	8200000	unpaid
2879	78	\N	\N	2023-05-20	2023-06-20	8200000	unpaid
2880	78	\N	\N	2023-06-20	2023-07-20	8200000	unpaid
2891	79	\N	\N	2023-02-10	2023-03-10	6900000	unpaid
2892	79	\N	\N	2023-03-10	2023-04-10	6900000	unpaid
2893	79	\N	\N	2023-04-10	2023-05-10	6900000	unpaid
2894	79	\N	\N	2023-05-10	2023-06-10	6900000	unpaid
2895	79	\N	\N	2023-06-10	2023-07-10	6900000	unpaid
2896	79	\N	\N	2023-07-10	2023-08-10	6900000	unpaid
2897	79	\N	\N	2023-08-10	2023-09-10	6900000	unpaid
2898	79	\N	\N	2023-09-10	2023-10-10	6900000	unpaid
2899	79	\N	\N	2023-10-10	2023-11-10	6900000	unpaid
2900	79	\N	\N	2023-11-10	2023-12-10	6900000	unpaid
2901	79	\N	\N	2023-12-10	2024-01-10	6900000	unpaid
2902	79	\N	\N	2024-01-10	2024-02-10	6900000	unpaid
2903	79	\N	\N	2024-02-10	2024-03-10	6900000	unpaid
2904	79	\N	\N	2024-03-10	2024-04-10	6900000	unpaid
2905	79	\N	\N	2024-04-10	2024-05-10	6900000	unpaid
2906	79	\N	\N	2024-05-10	2024-06-10	6900000	unpaid
2907	79	\N	\N	2024-06-10	2024-07-10	6900000	unpaid
2908	79	\N	\N	2024-07-10	2024-08-10	6900000	unpaid
2909	79	\N	\N	2024-08-10	2024-09-10	6900000	unpaid
2910	79	\N	\N	2024-09-10	2024-10-10	6900000	unpaid
2911	79	\N	\N	2024-10-10	2024-11-10	6900000	unpaid
2912	79	\N	\N	2024-11-10	2024-12-10	6900000	unpaid
2913	79	\N	\N	2024-12-10	2025-01-10	6900000	unpaid
2914	79	\N	\N	2025-01-10	2025-02-10	6900000	unpaid
2915	79	\N	\N	2025-02-10	2025-03-10	6900000	unpaid
2916	79	\N	\N	2025-03-10	2025-04-10	6900000	unpaid
2917	79	\N	\N	2025-04-10	2025-05-10	6900000	unpaid
2918	79	\N	\N	2025-05-10	2025-06-10	6900000	unpaid
2919	79	\N	\N	2025-06-10	2025-07-10	6900000	unpaid
2920	79	\N	\N	2025-07-10	2025-08-10	6900000	unpaid
2921	79	\N	\N	2025-08-10	2025-09-10	6900000	unpaid
2922	79	\N	\N	2025-09-10	2025-10-10	6900000	unpaid
2923	79	\N	\N	2025-10-10	2025-11-10	6900000	unpaid
2924	79	\N	\N	2025-11-10	2025-12-10	6900000	unpaid
2925	79	\N	\N	2025-12-10	2026-01-10	6900000	unpaid
2926	79	\N	\N	2026-01-10	2026-02-10	6900000	unpaid
2927	79	\N	\N	2026-02-10	2026-03-10	6900000	unpaid
2928	79	\N	\N	2026-03-10	2026-04-10	6900000	unpaid
2929	79	\N	\N	2026-04-10	2026-05-10	6900000	unpaid
2930	79	\N	\N	2026-05-10	2026-06-10	6900000	unpaid
2931	79	\N	\N	2026-06-10	2026-07-10	6900000	unpaid
2932	79	\N	\N	2026-07-10	2026-08-10	6900000	unpaid
2933	79	\N	\N	2026-08-10	2026-09-10	6900000	unpaid
2934	79	\N	\N	2026-09-10	2026-10-10	6900000	unpaid
2935	79	\N	\N	2026-10-10	2026-11-10	6900000	unpaid
2936	79	\N	\N	2026-11-10	2026-12-10	6900000	unpaid
2937	79	\N	\N	2026-12-10	2027-01-10	6900000	unpaid
2938	79	\N	\N	2027-01-10	2027-02-10	6900000	unpaid
2939	79	\N	\N	2027-02-10	2027-03-10	6900000	unpaid
2940	79	\N	\N	2027-03-10	2027-04-10	6900000	unpaid
161	5	2022-10-05	cash	2022-10-12	2022-11-12	700000	paid
162	5	2022-11-05	cash	2022-11-12	2022-12-12	700000	paid
169	6	2022-10-04	cash	2022-10-11	2022-11-11	3300000	paid
3004	82	\N	\N	2023-02-26	2023-03-26	7900000	unpaid
3005	82	\N	\N	2023-03-26	2023-04-26	7900000	unpaid
3006	82	\N	\N	2023-04-26	2023-05-26	7900000	unpaid
3007	82	\N	\N	2023-05-26	2023-06-26	7900000	unpaid
3008	82	\N	\N	2023-06-26	2023-07-26	7900000	unpaid
3009	82	\N	\N	2023-07-26	2023-08-26	7900000	unpaid
3010	82	\N	\N	2023-08-26	2023-09-26	7900000	unpaid
3011	82	\N	\N	2023-09-26	2023-10-26	7900000	unpaid
3012	82	\N	\N	2023-10-26	2023-11-26	7900000	unpaid
3030	84	\N	\N	2023-02-07	2023-03-07	2400000	unpaid
3031	84	\N	\N	2023-03-07	2023-04-07	2400000	unpaid
3032	84	\N	\N	2023-04-07	2023-05-07	2400000	unpaid
3033	84	\N	\N	2023-05-07	2023-06-07	2400000	unpaid
3034	84	\N	\N	2023-06-07	2023-07-07	2400000	unpaid
3035	84	\N	\N	2023-07-07	2023-08-07	2400000	unpaid
3036	84	\N	\N	2023-08-07	2023-09-07	2400000	unpaid
3037	84	\N	\N	2023-09-07	2023-10-07	2400000	unpaid
3038	84	\N	\N	2023-10-07	2023-11-07	2400000	unpaid
3039	84	\N	\N	2023-11-07	2023-12-07	2400000	unpaid
3040	84	\N	\N	2023-12-07	2024-01-07	2400000	unpaid
3041	84	\N	\N	2024-01-07	2024-02-07	2400000	unpaid
3042	84	\N	\N	2024-02-07	2024-03-07	2400000	unpaid
3043	84	\N	\N	2024-03-07	2024-04-07	2400000	unpaid
3044	84	\N	\N	2024-04-07	2024-05-07	2400000	unpaid
3045	84	\N	\N	2024-05-07	2024-06-07	2400000	unpaid
3046	84	\N	\N	2024-06-07	2024-07-07	2400000	unpaid
3047	84	\N	\N	2024-07-07	2024-08-07	2400000	unpaid
3048	84	\N	\N	2024-08-07	2024-09-07	2400000	unpaid
3049	84	\N	\N	2024-09-07	2024-10-07	2400000	unpaid
3050	84	\N	\N	2024-10-07	2024-11-07	2400000	unpaid
3051	84	\N	\N	2024-11-07	2024-12-07	2400000	unpaid
3052	84	\N	\N	2024-12-07	2025-01-07	2400000	unpaid
3053	84	\N	\N	2025-01-07	2025-02-07	2400000	unpaid
3054	84	\N	\N	2025-02-07	2025-03-07	2400000	unpaid
3055	84	\N	\N	2025-03-07	2025-04-07	2400000	unpaid
3056	84	\N	\N	2025-04-07	2025-05-07	2400000	unpaid
3057	84	\N	\N	2025-05-07	2025-06-07	2400000	unpaid
3058	84	\N	\N	2025-06-07	2025-07-07	2400000	unpaid
3059	84	\N	\N	2025-07-07	2025-08-07	2400000	unpaid
3060	84	\N	\N	2025-08-07	2025-09-07	2400000	unpaid
3061	84	\N	\N	2025-09-07	2025-10-07	2400000	unpaid
3062	84	\N	\N	2025-10-07	2025-11-07	2400000	unpaid
3063	84	\N	\N	2025-11-07	2025-12-07	2400000	unpaid
3064	84	\N	\N	2025-12-07	2026-01-07	2400000	unpaid
3065	84	\N	\N	2026-01-07	2026-02-07	2400000	unpaid
3066	84	\N	\N	2026-02-07	2026-03-07	2400000	unpaid
3067	84	\N	\N	2026-03-07	2026-04-07	2400000	unpaid
3068	84	\N	\N	2026-04-07	2026-05-07	2400000	unpaid
3069	84	\N	\N	2026-05-07	2026-06-07	2400000	unpaid
3070	84	\N	\N	2026-06-07	2026-07-07	2400000	unpaid
3071	84	\N	\N	2026-07-07	2026-08-07	2400000	unpaid
3072	84	\N	\N	2026-08-07	2026-09-07	2400000	unpaid
3093	85	\N	\N	2023-02-28	2023-03-28	2900000	unpaid
3094	85	\N	\N	2023-03-28	2023-04-28	2900000	unpaid
3095	85	\N	\N	2023-04-28	2023-05-28	2900000	unpaid
3096	85	\N	\N	2023-05-28	2023-06-28	2900000	unpaid
3097	85	\N	\N	2023-06-28	2023-07-28	2900000	unpaid
3098	85	\N	\N	2023-07-28	2023-08-28	2900000	unpaid
3099	85	\N	\N	2023-08-28	2023-09-28	2900000	unpaid
3100	85	\N	\N	2023-09-28	2023-10-28	2900000	unpaid
3101	85	\N	\N	2023-10-28	2023-11-28	2900000	unpaid
3102	85	\N	\N	2023-11-28	2023-12-28	2900000	unpaid
3103	85	\N	\N	2023-12-28	2024-01-28	2900000	unpaid
3104	85	\N	\N	2024-01-28	2024-02-28	2900000	unpaid
3105	85	\N	\N	2024-02-28	2024-03-28	2900000	unpaid
3106	85	\N	\N	2024-03-28	2024-04-28	2900000	unpaid
3107	85	\N	\N	2024-04-28	2024-05-28	2900000	unpaid
3108	85	\N	\N	2024-05-28	2024-06-28	2900000	unpaid
3109	85	\N	\N	2024-06-28	2024-07-28	2900000	unpaid
3110	85	\N	\N	2024-07-28	2024-08-28	2900000	unpaid
3111	85	\N	\N	2024-08-28	2024-09-28	2900000	unpaid
3112	85	\N	\N	2024-09-28	2024-10-28	2900000	unpaid
3113	85	\N	\N	2024-10-28	2024-11-28	2900000	unpaid
3114	85	\N	\N	2024-11-28	2024-12-28	2900000	unpaid
3115	85	\N	\N	2024-12-28	2025-01-28	2900000	unpaid
3116	85	\N	\N	2025-01-28	2025-02-28	2900000	unpaid
3117	85	\N	\N	2025-02-28	2025-03-28	2900000	unpaid
3118	85	\N	\N	2025-03-28	2025-04-28	2900000	unpaid
3119	85	\N	\N	2025-04-28	2025-05-28	2900000	unpaid
3120	85	\N	\N	2025-05-28	2025-06-28	2900000	unpaid
3121	85	\N	\N	2025-06-28	2025-07-28	2900000	unpaid
3122	85	\N	\N	2025-07-28	2025-08-28	2900000	unpaid
3123	85	\N	\N	2025-08-28	2025-09-28	2900000	unpaid
3124	85	\N	\N	2025-09-28	2025-10-28	2900000	unpaid
3125	85	\N	\N	2025-10-28	2025-11-28	2900000	unpaid
3126	85	\N	\N	2025-11-28	2025-12-28	2900000	unpaid
3127	85	\N	\N	2025-12-28	2026-01-28	2900000	unpaid
3128	85	\N	\N	2026-01-28	2026-02-28	2900000	unpaid
170	6	2022-11-04	cash	2022-11-11	2022-12-11	3300000	paid
217	7	2020-05-10	cash	2020-05-17	2020-06-17	5800000	paid
218	7	2020-06-10	cash	2020-06-17	2020-07-17	5800000	paid
219	7	2020-07-10	cash	2020-07-17	2020-08-17	5800000	paid
220	7	2020-08-10	cash	2020-08-17	2020-09-17	5800000	paid
3129	85	\N	\N	2026-02-28	2026-03-28	2900000	unpaid
3130	85	\N	\N	2026-03-28	2026-04-28	2900000	unpaid
3131	85	\N	\N	2026-04-28	2026-05-28	2900000	unpaid
3132	85	\N	\N	2026-05-28	2026-06-28	2900000	unpaid
3188	86	\N	\N	2023-02-07	2023-03-07	7000000	unpaid
3189	86	\N	\N	2023-03-07	2023-04-07	7000000	unpaid
3190	86	\N	\N	2023-04-07	2023-05-07	7000000	unpaid
3191	86	\N	\N	2023-05-07	2023-06-07	7000000	unpaid
3192	86	\N	\N	2023-06-07	2023-07-07	7000000	unpaid
3202	87	\N	\N	2023-02-07	2023-03-07	400000	unpaid
3203	87	\N	\N	2023-03-07	2023-04-07	400000	unpaid
3204	87	\N	\N	2023-04-07	2023-05-07	400000	unpaid
3205	87	\N	\N	2023-05-07	2023-06-07	400000	unpaid
3206	87	\N	\N	2023-06-07	2023-07-07	400000	unpaid
3207	87	\N	\N	2023-07-07	2023-08-07	400000	unpaid
3208	87	\N	\N	2023-08-07	2023-09-07	400000	unpaid
3209	87	\N	\N	2023-09-07	2023-10-07	400000	unpaid
3210	87	\N	\N	2023-10-07	2023-11-07	400000	unpaid
3211	87	\N	\N	2023-11-07	2023-12-07	400000	unpaid
3212	87	\N	\N	2023-12-07	2024-01-07	400000	unpaid
3213	87	\N	\N	2024-01-07	2024-02-07	400000	unpaid
3214	87	\N	\N	2024-02-07	2024-03-07	400000	unpaid
3215	87	\N	\N	2024-03-07	2024-04-07	400000	unpaid
3216	87	\N	\N	2024-04-07	2024-05-07	400000	unpaid
221	7	2020-09-10	cash	2020-09-17	2020-10-17	5800000	paid
222	7	2020-10-10	cash	2020-10-17	2020-11-17	5800000	paid
223	7	2020-11-10	cash	2020-11-17	2020-12-17	5800000	paid
3282	92	\N	\N	2023-02-14	2023-03-14	1800000	unpaid
3283	92	\N	\N	2023-03-14	2023-04-14	1800000	unpaid
3284	92	\N	\N	2023-04-14	2023-05-14	1800000	unpaid
3285	92	\N	\N	2023-05-14	2023-06-14	1800000	unpaid
3286	92	\N	\N	2023-06-14	2023-07-14	1800000	unpaid
3287	92	\N	\N	2023-07-14	2023-08-14	1800000	unpaid
3288	92	\N	\N	2023-08-14	2023-09-14	1800000	unpaid
3370	95	\N	\N	2023-02-13	2023-03-13	700000	unpaid
3371	95	\N	\N	2023-03-13	2023-04-13	700000	unpaid
3372	95	\N	\N	2023-04-13	2023-05-13	700000	unpaid
3373	95	\N	\N	2023-05-13	2023-06-13	700000	unpaid
3374	95	\N	\N	2023-06-13	2023-07-13	700000	unpaid
3375	95	\N	\N	2023-07-13	2023-08-13	700000	unpaid
3376	95	\N	\N	2023-08-13	2023-09-13	700000	unpaid
3377	95	\N	\N	2023-09-13	2023-10-13	700000	unpaid
3378	95	\N	\N	2023-10-13	2023-11-13	700000	unpaid
3379	95	\N	\N	2023-11-13	2023-12-13	700000	unpaid
3380	95	\N	\N	2023-12-13	2024-01-13	700000	unpaid
3381	95	\N	\N	2024-01-13	2024-02-13	700000	unpaid
3382	95	\N	\N	2024-02-13	2024-03-13	700000	unpaid
3383	95	\N	\N	2024-03-13	2024-04-13	700000	unpaid
3384	95	\N	\N	2024-04-13	2024-05-13	700000	unpaid
3385	95	\N	\N	2024-05-13	2024-06-13	700000	unpaid
3386	95	\N	\N	2024-06-13	2024-07-13	700000	unpaid
3387	95	\N	\N	2024-07-13	2024-08-13	700000	unpaid
3388	95	\N	\N	2024-08-13	2024-09-13	700000	unpaid
3389	95	\N	\N	2024-09-13	2024-10-13	700000	unpaid
3390	95	\N	\N	2024-10-13	2024-11-13	700000	unpaid
3391	95	\N	\N	2024-11-13	2024-12-13	700000	unpaid
3392	95	\N	\N	2024-12-13	2025-01-13	700000	unpaid
3393	95	\N	\N	2025-01-13	2025-02-13	700000	unpaid
3394	95	\N	\N	2025-02-13	2025-03-13	700000	unpaid
3395	95	\N	\N	2025-03-13	2025-04-13	700000	unpaid
3396	95	\N	\N	2025-04-13	2025-05-13	700000	unpaid
3397	95	\N	\N	2025-05-13	2025-06-13	700000	unpaid
3398	95	\N	\N	2025-06-13	2025-07-13	700000	unpaid
3399	95	\N	\N	2025-07-13	2025-08-13	700000	unpaid
3400	95	\N	\N	2025-08-13	2025-09-13	700000	unpaid
224	7	2020-12-10	cash	2020-12-17	2021-01-17	5800000	paid
225	7	2021-01-10	cash	2021-01-17	2021-02-17	5800000	paid
226	7	2021-02-10	cash	2021-02-17	2021-03-17	5800000	paid
3401	95	\N	\N	2025-09-13	2025-10-13	700000	unpaid
3402	95	\N	\N	2025-10-13	2025-11-13	700000	unpaid
3403	95	\N	\N	2025-11-13	2025-12-13	700000	unpaid
3404	95	\N	\N	2025-12-13	2026-01-13	700000	unpaid
3405	95	\N	\N	2026-01-13	2026-02-13	700000	unpaid
3406	95	\N	\N	2026-02-13	2026-03-13	700000	unpaid
3407	95	\N	\N	2026-03-13	2026-04-13	700000	unpaid
3408	95	\N	\N	2026-04-13	2026-05-13	700000	unpaid
3411	96	\N	\N	2023-02-28	2023-03-28	8700000	unpaid
3412	96	\N	\N	2023-03-28	2023-04-28	8700000	unpaid
3413	96	\N	\N	2023-04-28	2023-05-28	8700000	unpaid
3414	96	\N	\N	2023-05-28	2023-06-28	8700000	unpaid
3415	96	\N	\N	2023-06-28	2023-07-28	8700000	unpaid
3416	96	\N	\N	2023-07-28	2023-08-28	8700000	unpaid
3417	96	\N	\N	2023-08-28	2023-09-28	8700000	unpaid
3418	96	\N	\N	2023-09-28	2023-10-28	8700000	unpaid
3419	96	\N	\N	2023-10-28	2023-11-28	8700000	unpaid
3420	96	\N	\N	2023-11-28	2023-12-28	8700000	unpaid
3421	96	\N	\N	2023-12-28	2024-01-28	8700000	unpaid
3422	96	\N	\N	2024-01-28	2024-02-28	8700000	unpaid
3423	96	\N	\N	2024-02-28	2024-03-28	8700000	unpaid
3424	96	\N	\N	2024-03-28	2024-04-28	8700000	unpaid
3425	96	\N	\N	2024-04-28	2024-05-28	8700000	unpaid
3426	96	\N	\N	2024-05-28	2024-06-28	8700000	unpaid
3427	96	\N	\N	2024-06-28	2024-07-28	8700000	unpaid
3428	96	\N	\N	2024-07-28	2024-08-28	8700000	unpaid
3429	96	\N	\N	2024-08-28	2024-09-28	8700000	unpaid
3430	96	\N	\N	2024-09-28	2024-10-28	8700000	unpaid
3431	96	\N	\N	2024-10-28	2024-11-28	8700000	unpaid
3432	96	\N	\N	2024-11-28	2024-12-28	8700000	unpaid
3433	96	\N	\N	2024-12-28	2025-01-28	8700000	unpaid
3434	96	\N	\N	2025-01-28	2025-02-28	8700000	unpaid
3435	96	\N	\N	2025-02-28	2025-03-28	8700000	unpaid
3436	96	\N	\N	2025-03-28	2025-04-28	8700000	unpaid
3437	96	\N	\N	2025-04-28	2025-05-28	8700000	unpaid
3438	96	\N	\N	2025-05-28	2025-06-28	8700000	unpaid
3439	96	\N	\N	2025-06-28	2025-07-28	8700000	unpaid
3440	96	\N	\N	2025-07-28	2025-08-28	8700000	unpaid
3441	96	\N	\N	2025-08-28	2025-09-28	8700000	unpaid
3442	96	\N	\N	2025-09-28	2025-10-28	8700000	unpaid
3443	96	\N	\N	2025-10-28	2025-11-28	8700000	unpaid
3444	96	\N	\N	2025-11-28	2025-12-28	8700000	unpaid
3445	96	\N	\N	2025-12-28	2026-01-28	8700000	unpaid
3446	96	\N	\N	2026-01-28	2026-02-28	8700000	unpaid
3447	96	\N	\N	2026-02-28	2026-03-28	8700000	unpaid
3448	96	\N	\N	2026-03-28	2026-04-28	8700000	unpaid
3449	96	\N	\N	2026-04-28	2026-05-28	8700000	unpaid
3450	96	\N	\N	2026-05-28	2026-06-28	8700000	unpaid
3451	96	\N	\N	2026-06-28	2026-07-28	8700000	unpaid
3452	96	\N	\N	2026-07-28	2026-08-28	8700000	unpaid
3453	96	\N	\N	2026-08-28	2026-09-28	8700000	unpaid
3454	96	\N	\N	2026-09-28	2026-10-28	8700000	unpaid
3455	96	\N	\N	2026-10-28	2026-11-28	8700000	unpaid
3456	96	\N	\N	2026-11-28	2026-12-28	8700000	unpaid
227	7	2021-03-10	cash	2021-03-17	2021-04-17	5800000	paid
228	7	2021-04-10	cash	2021-04-17	2021-05-17	5800000	paid
3538	98	\N	\N	2023-02-08	2023-03-08	4500000	unpaid
3539	98	\N	\N	2023-03-08	2023-04-08	4500000	unpaid
3540	98	\N	\N	2023-04-08	2023-05-08	4500000	unpaid
229	7	2021-05-10	cash	2021-05-17	2021-06-17	5800000	paid
230	7	2021-06-10	cash	2021-06-17	2021-07-17	5800000	paid
231	7	2021-07-10	cash	2021-07-17	2021-08-17	5800000	paid
232	7	2021-08-10	cash	2021-08-17	2021-09-17	5800000	paid
233	7	2021-09-10	cash	2021-09-17	2021-10-17	5800000	paid
234	7	2021-10-10	cash	2021-10-17	2021-11-17	5800000	paid
235	7	2021-11-10	cash	2021-11-17	2021-12-17	5800000	paid
236	7	2021-12-10	cash	2021-12-17	2022-01-17	5800000	paid
237	7	2022-01-10	cash	2022-01-17	2022-02-17	5800000	paid
238	7	2022-02-10	cash	2022-02-17	2022-03-17	5800000	paid
239	7	2022-03-10	cash	2022-03-17	2022-04-17	5800000	paid
240	7	2022-04-10	cash	2022-04-17	2022-05-17	5800000	paid
241	7	2022-05-10	cash	2022-05-17	2022-06-17	5800000	paid
242	7	2022-06-10	cash	2022-06-17	2022-07-17	5800000	paid
243	7	2022-07-10	cash	2022-07-17	2022-08-17	5800000	paid
244	7	2022-08-10	cash	2022-08-17	2022-09-17	5800000	paid
245	7	2022-09-10	cash	2022-09-17	2022-10-17	5800000	paid
246	7	2022-10-10	cash	2022-10-17	2022-11-17	5800000	paid
247	7	2022-11-10	cash	2022-11-17	2022-12-17	5800000	paid
277	8	2019-08-31	cash	2019-09-07	2019-10-07	3600000	paid
278	8	2019-09-30	cash	2019-10-07	2019-11-07	3600000	paid
279	8	2019-10-31	cash	2019-11-07	2019-12-07	3600000	paid
280	8	2019-11-30	cash	2019-12-07	2020-01-07	3600000	paid
281	8	2019-12-31	cash	2020-01-07	2020-02-07	3600000	paid
282	8	2020-01-31	cash	2020-02-07	2020-03-07	3600000	paid
283	8	2020-02-29	cash	2020-03-07	2020-04-07	3600000	paid
284	8	2020-03-31	cash	2020-04-07	2020-05-07	3600000	paid
285	8	2020-04-30	cash	2020-05-07	2020-06-07	3600000	paid
325	10	2022-12-20	cash	2022-12-27	2023-01-27	4300000	paid
326	10	2023-01-20	cash	2023-01-27	2023-02-27	4300000	paid
376	11	2022-12-17	cash	2022-12-24	2023-01-24	8300000	paid
377	11	2023-01-17	cash	2023-01-24	2023-02-24	8300000	paid
400	12	2022-12-15	cash	2022-12-22	2023-01-22	7700000	paid
401	12	2023-01-15	cash	2023-01-22	2023-02-22	7700000	paid
286	8	2020-05-31	cash	2020-06-07	2020-07-07	3600000	paid
287	8	2020-06-30	cash	2020-07-07	2020-08-07	3600000	paid
288	8	2020-07-31	cash	2020-08-07	2020-09-07	3600000	paid
289	8	2020-08-31	cash	2020-09-07	2020-10-07	3600000	paid
290	8	2020-09-30	cash	2020-10-07	2020-11-07	3600000	paid
291	8	2020-10-31	cash	2020-11-07	2020-12-07	3600000	paid
292	8	2020-11-30	cash	2020-12-07	2021-01-07	3600000	paid
293	8	2020-12-31	cash	2021-01-07	2021-02-07	3600000	paid
294	8	2021-01-31	cash	2021-02-07	2021-03-07	3600000	paid
295	8	2021-02-28	cash	2021-03-07	2021-04-07	3600000	paid
296	8	2021-03-31	cash	2021-04-07	2021-05-07	3600000	paid
297	8	2021-04-30	cash	2021-05-07	2021-06-07	3600000	paid
298	8	2021-05-31	cash	2021-06-07	2021-07-07	3600000	paid
299	8	2021-06-30	cash	2021-07-07	2021-08-07	3600000	paid
300	8	2021-07-31	cash	2021-08-07	2021-09-07	3600000	paid
301	8	2021-08-31	cash	2021-09-07	2021-10-07	3600000	paid
302	8	2021-09-30	cash	2021-10-07	2021-11-07	3600000	paid
303	8	2021-10-31	cash	2021-11-07	2021-12-07	3600000	paid
304	8	2021-11-30	cash	2021-12-07	2022-01-07	3600000	paid
305	8	2021-12-31	cash	2022-01-07	2022-02-07	3600000	paid
306	8	2022-01-31	cash	2022-02-07	2022-03-07	3600000	paid
307	8	2022-02-28	cash	2022-03-07	2022-04-07	3600000	paid
308	8	2022-03-31	cash	2022-04-07	2022-05-07	3600000	paid
309	8	2022-04-30	cash	2022-05-07	2022-06-07	3600000	paid
310	8	2022-05-31	cash	2022-06-07	2022-07-07	3600000	paid
311	8	2022-06-30	cash	2022-07-07	2022-08-07	3600000	paid
312	8	2022-07-31	cash	2022-08-07	2022-09-07	3600000	paid
313	9	2020-05-30	cash	2020-06-06	2020-07-06	1000000	paid
314	9	2020-06-29	cash	2020-07-06	2020-08-06	1000000	paid
315	9	2020-07-30	cash	2020-08-06	2020-09-06	1000000	paid
316	9	2020-08-30	cash	2020-09-06	2020-10-06	1000000	paid
317	9	2020-09-29	cash	2020-10-06	2020-11-06	1000000	paid
318	9	2020-10-30	cash	2020-11-06	2020-12-06	1000000	paid
319	9	2020-11-29	cash	2020-12-06	2021-01-06	1000000	paid
320	9	2020-12-30	cash	2021-01-06	2021-02-06	1000000	paid
321	9	2021-01-30	cash	2021-02-06	2021-03-06	1000000	paid
322	9	2021-02-27	cash	2021-03-06	2021-04-06	1000000	paid
323	9	2021-03-30	cash	2021-04-06	2021-05-06	1000000	paid
324	9	2021-04-29	cash	2021-05-06	2021-06-06	1000000	paid
349	11	2020-09-17	cash	2020-09-24	2020-10-24	8300000	paid
350	11	2020-10-17	cash	2020-10-24	2020-11-24	8300000	paid
351	11	2020-11-17	cash	2020-11-24	2020-12-24	8300000	paid
352	11	2020-12-17	cash	2020-12-24	2021-01-24	8300000	paid
353	11	2021-01-17	cash	2021-01-24	2021-02-24	8300000	paid
354	11	2021-02-17	cash	2021-02-24	2021-03-24	8300000	paid
355	11	2021-03-17	cash	2021-03-24	2021-04-24	8300000	paid
356	11	2021-04-17	cash	2021-04-24	2021-05-24	8300000	paid
357	11	2021-05-17	cash	2021-05-24	2021-06-24	8300000	paid
358	11	2021-06-17	cash	2021-06-24	2021-07-24	8300000	paid
359	11	2021-07-17	cash	2021-07-24	2021-08-24	8300000	paid
360	11	2021-08-17	cash	2021-08-24	2021-09-24	8300000	paid
361	11	2021-09-17	cash	2021-09-24	2021-10-24	8300000	paid
362	11	2021-10-17	cash	2021-10-24	2021-11-24	8300000	paid
363	11	2021-11-17	cash	2021-11-24	2021-12-24	8300000	paid
364	11	2021-12-17	cash	2021-12-24	2022-01-24	8300000	paid
365	11	2022-01-17	cash	2022-01-24	2022-02-24	8300000	paid
366	11	2022-02-17	cash	2022-02-24	2022-03-24	8300000	paid
367	11	2022-03-17	cash	2022-03-24	2022-04-24	8300000	paid
368	11	2022-04-17	cash	2022-04-24	2022-05-24	8300000	paid
369	11	2022-05-17	cash	2022-05-24	2022-06-24	8300000	paid
370	11	2022-06-17	cash	2022-06-24	2022-07-24	8300000	paid
371	11	2022-07-17	cash	2022-07-24	2022-08-24	8300000	paid
372	11	2022-08-17	cash	2022-08-24	2022-09-24	8300000	paid
373	11	2022-09-17	cash	2022-09-24	2022-10-24	8300000	paid
374	11	2022-10-17	cash	2022-10-24	2022-11-24	8300000	paid
375	11	2022-11-17	cash	2022-11-24	2022-12-24	8300000	paid
397	12	2022-09-15	cash	2022-09-22	2022-10-22	7700000	paid
398	12	2022-10-15	cash	2022-10-22	2022-11-22	7700000	paid
399	12	2022-11-15	cash	2022-11-22	2022-12-22	7700000	paid
421	13	2019-12-23	cash	2019-12-30	2020-01-30	3400000	paid
422	13	2020-01-23	cash	2020-01-30	2020-02-29	3400000	paid
423	13	2020-02-22	cash	2020-02-29	2020-03-29	3400000	paid
457	13	2022-12-21	cash	2022-12-28	2023-01-28	3400000	paid
458	13	2023-01-21	cash	2023-01-28	2023-02-28	3400000	paid
506	14	2022-11-25	cash	2022-12-02	2023-01-02	1100000	paid
507	14	2022-12-26	cash	2023-01-02	2023-02-02	1100000	paid
424	13	2020-03-22	cash	2020-03-29	2020-04-29	3400000	paid
425	13	2020-04-22	cash	2020-04-29	2020-05-29	3400000	paid
426	13	2020-05-22	cash	2020-05-29	2020-06-29	3400000	paid
427	13	2020-06-22	cash	2020-06-29	2020-07-29	3400000	paid
428	13	2020-07-22	cash	2020-07-29	2020-08-29	3400000	paid
429	13	2020-08-22	cash	2020-08-29	2020-09-29	3400000	paid
430	13	2020-09-22	cash	2020-09-29	2020-10-29	3400000	paid
431	13	2020-10-22	cash	2020-10-29	2020-11-29	3400000	paid
432	13	2020-11-22	cash	2020-11-29	2020-12-29	3400000	paid
433	13	2020-12-22	cash	2020-12-29	2021-01-29	3400000	paid
434	13	2021-01-22	cash	2021-01-29	2021-02-28	3400000	paid
435	13	2021-02-21	cash	2021-02-28	2021-03-28	3400000	paid
436	13	2021-03-21	cash	2021-03-28	2021-04-28	3400000	paid
437	13	2021-04-21	cash	2021-04-28	2021-05-28	3400000	paid
438	13	2021-05-21	cash	2021-05-28	2021-06-28	3400000	paid
439	13	2021-06-21	cash	2021-06-28	2021-07-28	3400000	paid
440	13	2021-07-21	cash	2021-07-28	2021-08-28	3400000	paid
441	13	2021-08-21	cash	2021-08-28	2021-09-28	3400000	paid
442	13	2021-09-21	cash	2021-09-28	2021-10-28	3400000	paid
443	13	2021-10-21	cash	2021-10-28	2021-11-28	3400000	paid
444	13	2021-11-21	cash	2021-11-28	2021-12-28	3400000	paid
445	13	2021-12-21	cash	2021-12-28	2022-01-28	3400000	paid
446	13	2022-01-21	cash	2022-01-28	2022-02-28	3400000	paid
447	13	2022-02-21	cash	2022-02-28	2022-03-28	3400000	paid
448	13	2022-03-21	cash	2022-03-28	2022-04-28	3400000	paid
449	13	2022-04-21	cash	2022-04-28	2022-05-28	3400000	paid
450	13	2022-05-21	cash	2022-05-28	2022-06-28	3400000	paid
451	13	2022-06-21	cash	2022-06-28	2022-07-28	3400000	paid
452	13	2022-07-21	cash	2022-07-28	2022-08-28	3400000	paid
453	13	2022-08-21	cash	2022-08-28	2022-09-28	3400000	paid
454	13	2022-09-21	cash	2022-09-28	2022-10-28	3400000	paid
455	13	2022-10-21	cash	2022-10-28	2022-11-28	3400000	paid
456	13	2022-11-21	cash	2022-11-28	2022-12-28	3400000	paid
469	14	2019-10-26	cash	2019-11-02	2019-12-02	1100000	paid
470	14	2019-11-25	cash	2019-12-02	2020-01-02	1100000	paid
471	14	2019-12-26	cash	2020-01-02	2020-02-02	1100000	paid
472	14	2020-01-26	cash	2020-02-02	2020-03-02	1100000	paid
473	14	2020-02-24	cash	2020-03-02	2020-04-02	1100000	paid
474	14	2020-03-26	cash	2020-04-02	2020-05-02	1100000	paid
475	14	2020-04-25	cash	2020-05-02	2020-06-02	1100000	paid
476	14	2020-05-26	cash	2020-06-02	2020-07-02	1100000	paid
477	14	2020-06-25	cash	2020-07-02	2020-08-02	1100000	paid
478	14	2020-07-26	cash	2020-08-02	2020-09-02	1100000	paid
479	14	2020-08-26	cash	2020-09-02	2020-10-02	1100000	paid
480	14	2020-09-25	cash	2020-10-02	2020-11-02	1100000	paid
481	14	2020-10-26	cash	2020-11-02	2020-12-02	1100000	paid
482	14	2020-11-25	cash	2020-12-02	2021-01-02	1100000	paid
483	14	2020-12-26	cash	2021-01-02	2021-02-02	1100000	paid
484	14	2021-01-26	cash	2021-02-02	2021-03-02	1100000	paid
485	14	2021-02-23	cash	2021-03-02	2021-04-02	1100000	paid
486	14	2021-03-26	cash	2021-04-02	2021-05-02	1100000	paid
487	14	2021-04-25	cash	2021-05-02	2021-06-02	1100000	paid
488	14	2021-05-26	cash	2021-06-02	2021-07-02	1100000	paid
489	14	2021-06-25	cash	2021-07-02	2021-08-02	1100000	paid
490	14	2021-07-26	cash	2021-08-02	2021-09-02	1100000	paid
491	14	2021-08-26	cash	2021-09-02	2021-10-02	1100000	paid
492	14	2021-09-25	cash	2021-10-02	2021-11-02	1100000	paid
493	14	2021-10-26	cash	2021-11-02	2021-12-02	1100000	paid
494	14	2021-11-25	cash	2021-12-02	2022-01-02	1100000	paid
495	14	2021-12-26	cash	2022-01-02	2022-02-02	1100000	paid
496	14	2022-01-26	cash	2022-02-02	2022-03-02	1100000	paid
497	14	2022-02-23	cash	2022-03-02	2022-04-02	1100000	paid
498	14	2022-03-26	cash	2022-04-02	2022-05-02	1100000	paid
499	14	2022-04-25	cash	2022-05-02	2022-06-02	1100000	paid
500	14	2022-05-26	cash	2022-06-02	2022-07-02	1100000	paid
501	14	2022-06-25	cash	2022-07-02	2022-08-02	1100000	paid
502	14	2022-07-26	cash	2022-08-02	2022-09-02	1100000	paid
503	14	2022-08-26	cash	2022-09-02	2022-10-02	1100000	paid
504	14	2022-09-25	cash	2022-10-02	2022-11-02	1100000	paid
505	14	2022-10-26	cash	2022-11-02	2022-12-02	1100000	paid
529	15	2019-04-08	cash	2019-04-15	2019-05-15	1200000	paid
530	15	2019-05-08	cash	2019-05-15	2019-06-15	1200000	paid
531	15	2019-06-08	cash	2019-06-15	2019-07-15	1200000	paid
532	15	2019-07-08	cash	2019-07-15	2019-08-15	1200000	paid
533	15	2019-08-08	cash	2019-08-15	2019-09-15	1200000	paid
534	15	2019-09-08	cash	2019-09-15	2019-10-15	1200000	paid
535	15	2019-10-08	cash	2019-10-15	2019-11-15	1200000	paid
536	15	2019-11-08	cash	2019-11-15	2019-12-15	1200000	paid
537	15	2019-12-08	cash	2019-12-15	2020-01-15	1200000	paid
538	15	2020-01-08	cash	2020-01-15	2020-02-15	1200000	paid
539	15	2020-02-08	cash	2020-02-15	2020-03-15	1200000	paid
540	15	2020-03-08	cash	2020-03-15	2020-04-15	1200000	paid
541	15	2020-04-08	cash	2020-04-15	2020-05-15	1200000	paid
542	15	2020-05-08	cash	2020-05-15	2020-06-15	1200000	paid
543	15	2020-06-08	cash	2020-06-15	2020-07-15	1200000	paid
573	15	2022-12-08	cash	2022-12-15	2023-01-15	1200000	paid
574	15	2023-01-08	cash	2023-01-15	2023-02-15	1200000	paid
593	16	2022-11-27	cash	2022-12-04	2023-01-04	7500000	paid
594	16	2022-12-28	cash	2023-01-04	2023-02-04	7500000	paid
544	15	2020-07-08	cash	2020-07-15	2020-08-15	1200000	paid
545	15	2020-08-08	cash	2020-08-15	2020-09-15	1200000	paid
546	15	2020-09-08	cash	2020-09-15	2020-10-15	1200000	paid
547	15	2020-10-08	cash	2020-10-15	2020-11-15	1200000	paid
548	15	2020-11-08	cash	2020-11-15	2020-12-15	1200000	paid
549	15	2020-12-08	cash	2020-12-15	2021-01-15	1200000	paid
550	15	2021-01-08	cash	2021-01-15	2021-02-15	1200000	paid
551	15	2021-02-08	cash	2021-02-15	2021-03-15	1200000	paid
552	15	2021-03-08	cash	2021-03-15	2021-04-15	1200000	paid
553	15	2021-04-08	cash	2021-04-15	2021-05-15	1200000	paid
554	15	2021-05-08	cash	2021-05-15	2021-06-15	1200000	paid
555	15	2021-06-08	cash	2021-06-15	2021-07-15	1200000	paid
556	15	2021-07-08	cash	2021-07-15	2021-08-15	1200000	paid
557	15	2021-08-08	cash	2021-08-15	2021-09-15	1200000	paid
558	15	2021-09-08	cash	2021-09-15	2021-10-15	1200000	paid
559	15	2021-10-08	cash	2021-10-15	2021-11-15	1200000	paid
560	15	2021-11-08	cash	2021-11-15	2021-12-15	1200000	paid
561	15	2021-12-08	cash	2021-12-15	2022-01-15	1200000	paid
562	15	2022-01-08	cash	2022-01-15	2022-02-15	1200000	paid
563	15	2022-02-08	cash	2022-02-15	2022-03-15	1200000	paid
564	15	2022-03-08	cash	2022-03-15	2022-04-15	1200000	paid
565	15	2022-04-08	cash	2022-04-15	2022-05-15	1200000	paid
566	15	2022-05-08	cash	2022-05-15	2022-06-15	1200000	paid
567	15	2022-06-08	cash	2022-06-15	2022-07-15	1200000	paid
568	15	2022-07-08	cash	2022-07-15	2022-08-15	1200000	paid
569	15	2022-08-08	cash	2022-08-15	2022-09-15	1200000	paid
570	15	2022-09-08	cash	2022-09-15	2022-10-15	1200000	paid
571	15	2022-10-08	cash	2022-10-15	2022-11-15	1200000	paid
572	15	2022-11-08	cash	2022-11-15	2022-12-15	1200000	paid
589	16	2022-07-28	cash	2022-08-04	2022-09-04	7500000	paid
590	16	2022-08-28	cash	2022-09-04	2022-10-04	7500000	paid
591	16	2022-09-27	cash	2022-10-04	2022-11-04	7500000	paid
592	16	2022-10-28	cash	2022-11-04	2022-12-04	7500000	paid
649	17	2019-08-04	cash	2019-08-11	2019-09-11	9200000	paid
650	17	2019-09-04	cash	2019-09-11	2019-10-11	9200000	paid
651	17	2019-10-04	cash	2019-10-11	2019-11-11	9200000	paid
652	17	2019-11-04	cash	2019-11-11	2019-12-11	9200000	paid
653	17	2019-12-04	cash	2019-12-11	2020-01-11	9200000	paid
654	17	2020-01-04	cash	2020-01-11	2020-02-11	9200000	paid
655	17	2020-02-04	cash	2020-02-11	2020-03-11	9200000	paid
656	17	2020-03-04	cash	2020-03-11	2020-04-11	9200000	paid
657	17	2020-04-04	cash	2020-04-11	2020-05-11	9200000	paid
658	17	2020-05-04	cash	2020-05-11	2020-06-11	9200000	paid
659	17	2020-06-04	cash	2020-06-11	2020-07-11	9200000	paid
660	17	2020-07-04	cash	2020-07-11	2020-08-11	9200000	paid
661	17	2020-08-04	cash	2020-08-11	2020-09-11	9200000	paid
662	17	2020-09-04	cash	2020-09-11	2020-10-11	9200000	paid
663	17	2020-10-04	cash	2020-10-11	2020-11-11	9200000	paid
664	17	2020-11-04	cash	2020-11-11	2020-12-11	9200000	paid
665	17	2020-12-04	cash	2020-12-11	2021-01-11	9200000	paid
666	17	2021-01-04	cash	2021-01-11	2021-02-11	9200000	paid
667	17	2021-02-04	cash	2021-02-11	2021-03-11	9200000	paid
668	17	2021-03-04	cash	2021-03-11	2021-04-11	9200000	paid
669	17	2021-04-04	cash	2021-04-11	2021-05-11	9200000	paid
670	17	2021-05-04	cash	2021-05-11	2021-06-11	9200000	paid
671	17	2021-06-04	cash	2021-06-11	2021-07-11	9200000	paid
672	17	2021-07-04	cash	2021-07-11	2021-08-11	9200000	paid
673	17	2021-08-04	cash	2021-08-11	2021-09-11	9200000	paid
674	17	2021-09-04	cash	2021-09-11	2021-10-11	9200000	paid
675	17	2021-10-04	cash	2021-10-11	2021-11-11	9200000	paid
689	17	2022-12-04	cash	2022-12-11	2023-01-11	9200000	paid
690	17	2023-01-04	cash	2023-01-11	2023-02-11	9200000	paid
719	18	2022-12-12	cash	2022-12-19	2023-01-19	7400000	paid
720	18	2023-01-12	cash	2023-01-19	2023-02-19	7400000	paid
773	20	2022-12-10	cash	2022-12-17	2023-01-17	6600000	paid
774	20	2023-01-10	cash	2023-01-17	2023-02-17	6600000	paid
676	17	2021-11-04	cash	2021-11-11	2021-12-11	9200000	paid
677	17	2021-12-04	cash	2021-12-11	2022-01-11	9200000	paid
678	17	2022-01-04	cash	2022-01-11	2022-02-11	9200000	paid
679	17	2022-02-04	cash	2022-02-11	2022-03-11	9200000	paid
680	17	2022-03-04	cash	2022-03-11	2022-04-11	9200000	paid
681	17	2022-04-04	cash	2022-04-11	2022-05-11	9200000	paid
682	17	2022-05-04	cash	2022-05-11	2022-06-11	9200000	paid
683	17	2022-06-04	cash	2022-06-11	2022-07-11	9200000	paid
684	17	2022-07-04	cash	2022-07-11	2022-08-11	9200000	paid
685	17	2022-08-04	cash	2022-08-11	2022-09-11	9200000	paid
686	17	2022-09-04	cash	2022-09-11	2022-10-11	9200000	paid
687	17	2022-10-04	cash	2022-10-11	2022-11-11	9200000	paid
688	17	2022-11-04	cash	2022-11-11	2022-12-11	9200000	paid
697	18	2021-02-12	cash	2021-02-19	2021-03-19	7400000	paid
698	18	2021-03-12	cash	2021-03-19	2021-04-19	7400000	paid
699	18	2021-04-12	cash	2021-04-19	2021-05-19	7400000	paid
700	18	2021-05-12	cash	2021-05-19	2021-06-19	7400000	paid
701	18	2021-06-12	cash	2021-06-19	2021-07-19	7400000	paid
702	18	2021-07-12	cash	2021-07-19	2021-08-19	7400000	paid
703	18	2021-08-12	cash	2021-08-19	2021-09-19	7400000	paid
704	18	2021-09-12	cash	2021-09-19	2021-10-19	7400000	paid
705	18	2021-10-12	cash	2021-10-19	2021-11-19	7400000	paid
706	18	2021-11-12	cash	2021-11-19	2021-12-19	7400000	paid
707	18	2021-12-12	cash	2021-12-19	2022-01-19	7400000	paid
708	18	2022-01-12	cash	2022-01-19	2022-02-19	7400000	paid
709	18	2022-02-12	cash	2022-02-19	2022-03-19	7400000	paid
710	18	2022-03-12	cash	2022-03-19	2022-04-19	7400000	paid
711	18	2022-04-12	cash	2022-04-19	2022-05-19	7400000	paid
712	18	2022-05-12	cash	2022-05-19	2022-06-19	7400000	paid
713	18	2022-06-12	cash	2022-06-19	2022-07-19	7400000	paid
714	18	2022-07-12	cash	2022-07-19	2022-08-19	7400000	paid
715	18	2022-08-12	cash	2022-08-19	2022-09-19	7400000	paid
716	18	2022-09-12	cash	2022-09-19	2022-10-19	7400000	paid
717	18	2022-10-12	cash	2022-10-19	2022-11-19	7400000	paid
718	18	2022-11-12	cash	2022-11-19	2022-12-19	7400000	paid
745	19	2018-05-08	cash	2018-05-15	2018-06-15	5200000	paid
746	19	2018-06-08	cash	2018-06-15	2018-07-15	5200000	paid
747	19	2018-07-08	cash	2018-07-15	2018-08-15	5200000	paid
748	19	2018-08-08	cash	2018-08-15	2018-09-15	5200000	paid
749	19	2018-09-08	cash	2018-09-15	2018-10-15	5200000	paid
750	19	2018-10-08	cash	2018-10-15	2018-11-15	5200000	paid
751	19	2018-11-08	cash	2018-11-15	2018-12-15	5200000	paid
752	19	2018-12-08	cash	2018-12-15	2019-01-15	5200000	paid
753	19	2019-01-08	cash	2019-01-15	2019-02-15	5200000	paid
754	19	2019-02-08	cash	2019-02-15	2019-03-15	5200000	paid
755	19	2019-03-08	cash	2019-03-15	2019-04-15	5200000	paid
756	19	2019-04-08	cash	2019-04-15	2019-05-15	5200000	paid
757	19	2019-05-08	cash	2019-05-15	2019-06-15	5200000	paid
758	19	2019-06-08	cash	2019-06-15	2019-07-15	5200000	paid
759	19	2019-07-08	cash	2019-07-15	2019-08-15	5200000	paid
760	19	2019-08-08	cash	2019-08-15	2019-09-15	5200000	paid
761	19	2019-09-08	cash	2019-09-15	2019-10-15	5200000	paid
865	23	2022-12-09	cash	2022-12-16	2023-01-16	3700000	paid
866	23	2023-01-09	cash	2023-01-16	2023-02-16	3700000	paid
762	19	2019-10-08	cash	2019-10-15	2019-11-15	5200000	paid
763	19	2019-11-08	cash	2019-11-15	2019-12-15	5200000	paid
764	19	2019-12-08	cash	2019-12-15	2020-01-15	5200000	paid
765	19	2020-01-08	cash	2020-01-15	2020-02-15	5200000	paid
766	19	2020-02-08	cash	2020-02-15	2020-03-15	5200000	paid
767	19	2020-03-08	cash	2020-03-15	2020-04-15	5200000	paid
768	19	2020-04-08	cash	2020-04-15	2020-05-15	5200000	paid
769	20	2022-08-10	cash	2022-08-17	2022-09-17	6600000	paid
770	20	2022-09-10	cash	2022-09-17	2022-10-17	6600000	paid
771	20	2022-10-10	cash	2022-10-17	2022-11-17	6600000	paid
772	20	2022-11-10	cash	2022-11-17	2022-12-17	6600000	paid
829	21	2019-12-12	cash	2019-12-19	2020-01-19	1100000	paid
830	21	2020-01-12	cash	2020-01-19	2020-02-19	1100000	paid
831	21	2020-02-12	cash	2020-02-19	2020-03-19	1100000	paid
832	21	2020-03-12	cash	2020-03-19	2020-04-19	1100000	paid
833	21	2020-04-12	cash	2020-04-19	2020-05-19	1100000	paid
834	21	2020-05-12	cash	2020-05-19	2020-06-19	1100000	paid
835	21	2020-06-12	cash	2020-06-19	2020-07-19	1100000	paid
836	21	2020-07-12	cash	2020-07-19	2020-08-19	1100000	paid
837	21	2020-08-12	cash	2020-08-19	2020-09-19	1100000	paid
838	21	2020-09-12	cash	2020-09-19	2020-10-19	1100000	paid
839	21	2020-10-12	cash	2020-10-19	2020-11-19	1100000	paid
840	21	2020-11-12	cash	2020-11-19	2020-12-19	1100000	paid
841	22	2019-02-10	cash	2019-02-17	2019-03-17	4300000	paid
842	22	2019-03-10	cash	2019-03-17	2019-04-17	4300000	paid
843	22	2019-04-10	cash	2019-04-17	2019-05-17	4300000	paid
844	22	2019-05-10	cash	2019-05-17	2019-06-17	4300000	paid
845	22	2019-06-10	cash	2019-06-17	2019-07-17	4300000	paid
846	22	2019-07-10	cash	2019-07-17	2019-08-17	4300000	paid
847	22	2019-08-10	cash	2019-08-17	2019-09-17	4300000	paid
848	22	2019-09-10	cash	2019-09-17	2019-10-17	4300000	paid
849	22	2019-10-10	cash	2019-10-17	2019-11-17	4300000	paid
850	22	2019-11-10	cash	2019-11-17	2019-12-17	4300000	paid
851	22	2019-12-10	cash	2019-12-17	2020-01-17	4300000	paid
852	22	2020-01-10	cash	2020-01-17	2020-02-17	4300000	paid
853	23	2021-12-09	cash	2021-12-16	2022-01-16	3700000	paid
854	23	2022-01-09	cash	2022-01-16	2022-02-16	3700000	paid
855	23	2022-02-09	cash	2022-02-16	2022-03-16	3700000	paid
856	23	2022-03-09	cash	2022-03-16	2022-04-16	3700000	paid
857	23	2022-04-09	cash	2022-04-16	2022-05-16	3700000	paid
858	23	2022-05-09	cash	2022-05-16	2022-06-16	3700000	paid
859	23	2022-06-09	cash	2022-06-16	2022-07-16	3700000	paid
860	23	2022-07-09	cash	2022-07-16	2022-08-16	3700000	paid
861	23	2022-08-09	cash	2022-08-16	2022-09-16	3700000	paid
862	23	2022-09-09	cash	2022-09-16	2022-10-16	3700000	paid
863	23	2022-10-09	cash	2022-10-16	2022-11-16	3700000	paid
864	23	2022-11-09	cash	2022-11-16	2022-12-16	3700000	paid
901	24	2018-08-01	cash	2018-08-08	2018-09-08	1400000	paid
902	24	2018-09-01	cash	2018-09-08	2018-10-08	1400000	paid
903	24	2018-10-01	cash	2018-10-08	2018-11-08	1400000	paid
904	24	2018-11-01	cash	2018-11-08	2018-12-08	1400000	paid
905	24	2018-12-01	cash	2018-12-08	2019-01-08	1400000	paid
906	24	2019-01-01	cash	2019-01-08	2019-02-08	1400000	paid
907	24	2019-02-01	cash	2019-02-08	2019-03-08	1400000	paid
908	24	2019-03-01	cash	2019-03-08	2019-04-08	1400000	paid
909	24	2019-04-01	cash	2019-04-08	2019-05-08	1400000	paid
910	24	2019-05-01	cash	2019-05-08	2019-06-08	1400000	paid
911	24	2019-06-01	cash	2019-06-08	2019-07-08	1400000	paid
912	24	2019-07-01	cash	2019-07-08	2019-08-08	1400000	paid
913	24	2019-08-01	cash	2019-08-08	2019-09-08	1400000	paid
914	24	2019-09-01	cash	2019-09-08	2019-10-08	1400000	paid
915	24	2019-10-01	cash	2019-10-08	2019-11-08	1400000	paid
916	24	2019-11-01	cash	2019-11-08	2019-12-08	1400000	paid
917	24	2019-12-01	cash	2019-12-08	2020-01-08	1400000	paid
918	24	2020-01-01	cash	2020-01-08	2020-02-08	1400000	paid
919	24	2020-02-01	cash	2020-02-08	2020-03-08	1400000	paid
920	24	2020-03-01	cash	2020-03-08	2020-04-08	1400000	paid
921	24	2020-04-01	cash	2020-04-08	2020-05-08	1400000	paid
922	24	2020-05-01	cash	2020-05-08	2020-06-08	1400000	paid
923	24	2020-06-01	cash	2020-06-08	2020-07-08	1400000	paid
924	24	2020-07-01	cash	2020-07-08	2020-08-08	1400000	paid
925	24	2020-08-01	cash	2020-08-08	2020-09-08	1400000	paid
926	24	2020-09-01	cash	2020-09-08	2020-10-08	1400000	paid
927	24	2020-10-01	cash	2020-10-08	2020-11-08	1400000	paid
928	24	2020-11-01	cash	2020-11-08	2020-12-08	1400000	paid
929	24	2020-12-01	cash	2020-12-08	2021-01-08	1400000	paid
930	24	2021-01-01	cash	2021-01-08	2021-02-08	1400000	paid
931	24	2021-02-01	cash	2021-02-08	2021-03-08	1400000	paid
932	24	2021-03-01	cash	2021-03-08	2021-04-08	1400000	paid
933	24	2021-04-01	cash	2021-04-08	2021-05-08	1400000	paid
934	24	2021-05-01	cash	2021-05-08	2021-06-08	1400000	paid
935	24	2021-06-01	cash	2021-06-08	2021-07-08	1400000	paid
936	24	2021-07-01	cash	2021-07-08	2021-08-08	1400000	paid
937	24	2021-08-01	cash	2021-08-08	2021-09-08	1400000	paid
938	24	2021-09-01	cash	2021-09-08	2021-10-08	1400000	paid
939	24	2021-10-01	cash	2021-10-08	2021-11-08	1400000	paid
970	25	2022-12-19	cash	2022-12-26	2023-01-26	800000	paid
971	25	2023-01-19	cash	2023-01-26	2023-02-26	800000	paid
1009	26	2022-12-21	cash	2022-12-28	2023-01-28	1400000	paid
1010	26	2023-01-21	cash	2023-01-28	2023-02-28	1400000	paid
1069	27	2022-12-05	cash	2022-12-12	2023-01-12	2200000	paid
1070	27	2023-01-05	cash	2023-01-12	2023-02-12	2200000	paid
940	24	2021-11-01	cash	2021-11-08	2021-12-08	1400000	paid
941	24	2021-12-01	cash	2021-12-08	2022-01-08	1400000	paid
942	24	2022-01-01	cash	2022-01-08	2022-02-08	1400000	paid
943	24	2022-02-01	cash	2022-02-08	2022-03-08	1400000	paid
944	24	2022-03-01	cash	2022-03-08	2022-04-08	1400000	paid
945	24	2022-04-01	cash	2022-04-08	2022-05-08	1400000	paid
946	24	2022-05-01	cash	2022-05-08	2022-06-08	1400000	paid
947	24	2022-06-01	cash	2022-06-08	2022-07-08	1400000	paid
948	24	2022-07-01	cash	2022-07-08	2022-08-08	1400000	paid
949	25	2021-03-19	cash	2021-03-26	2021-04-26	800000	paid
950	25	2021-04-19	cash	2021-04-26	2021-05-26	800000	paid
951	25	2021-05-19	cash	2021-05-26	2021-06-26	800000	paid
952	25	2021-06-19	cash	2021-06-26	2021-07-26	800000	paid
953	25	2021-07-19	cash	2021-07-26	2021-08-26	800000	paid
954	25	2021-08-19	cash	2021-08-26	2021-09-26	800000	paid
955	25	2021-09-19	cash	2021-09-26	2021-10-26	800000	paid
956	25	2021-10-19	cash	2021-10-26	2021-11-26	800000	paid
957	25	2021-11-19	cash	2021-11-26	2021-12-26	800000	paid
958	25	2021-12-19	cash	2021-12-26	2022-01-26	800000	paid
959	25	2022-01-19	cash	2022-01-26	2022-02-26	800000	paid
960	25	2022-02-19	cash	2022-02-26	2022-03-26	800000	paid
961	25	2022-03-19	cash	2022-03-26	2022-04-26	800000	paid
962	25	2022-04-19	cash	2022-04-26	2022-05-26	800000	paid
963	25	2022-05-19	cash	2022-05-26	2022-06-26	800000	paid
964	25	2022-06-19	cash	2022-06-26	2022-07-26	800000	paid
965	25	2022-07-19	cash	2022-07-26	2022-08-26	800000	paid
966	25	2022-08-19	cash	2022-08-26	2022-09-26	800000	paid
967	25	2022-09-19	cash	2022-09-26	2022-10-26	800000	paid
968	25	2022-10-19	cash	2022-10-26	2022-11-26	800000	paid
969	25	2022-11-19	cash	2022-11-26	2022-12-26	800000	paid
997	26	2021-12-24	cash	2021-12-31	2022-01-31	1400000	paid
998	26	2022-01-24	cash	2022-01-31	2022-02-28	1400000	paid
999	26	2022-02-21	cash	2022-02-28	2022-03-28	1400000	paid
1000	26	2022-03-21	cash	2022-03-28	2022-04-28	1400000	paid
1001	26	2022-04-21	cash	2022-04-28	2022-05-28	1400000	paid
1002	26	2022-05-21	cash	2022-05-28	2022-06-28	1400000	paid
1003	26	2022-06-21	cash	2022-06-28	2022-07-28	1400000	paid
1004	26	2022-07-21	cash	2022-07-28	2022-08-28	1400000	paid
1005	26	2022-08-21	cash	2022-08-28	2022-09-28	1400000	paid
1006	26	2022-09-21	cash	2022-09-28	2022-10-28	1400000	paid
1007	26	2022-10-21	cash	2022-10-28	2022-11-28	1400000	paid
1008	26	2022-11-21	cash	2022-11-28	2022-12-28	1400000	paid
1045	27	2020-12-05	cash	2020-12-12	2021-01-12	2200000	paid
1046	27	2021-01-05	cash	2021-01-12	2021-02-12	2200000	paid
1047	27	2021-02-05	cash	2021-02-12	2021-03-12	2200000	paid
1048	27	2021-03-05	cash	2021-03-12	2021-04-12	2200000	paid
1049	27	2021-04-05	cash	2021-04-12	2021-05-12	2200000	paid
1050	27	2021-05-05	cash	2021-05-12	2021-06-12	2200000	paid
1051	27	2021-06-05	cash	2021-06-12	2021-07-12	2200000	paid
1052	27	2021-07-05	cash	2021-07-12	2021-08-12	2200000	paid
1053	27	2021-08-05	cash	2021-08-12	2021-09-12	2200000	paid
1054	27	2021-09-05	cash	2021-09-12	2021-10-12	2200000	paid
1055	27	2021-10-05	cash	2021-10-12	2021-11-12	2200000	paid
1056	27	2021-11-05	cash	2021-11-12	2021-12-12	2200000	paid
1057	27	2021-12-05	cash	2021-12-12	2022-01-12	2200000	paid
1117	29	2022-12-05	cash	2022-12-12	2023-01-12	1900000	paid
1118	29	2023-01-05	cash	2023-01-12	2023-02-12	1900000	paid
1199	33	2022-12-09	cash	2022-12-16	2023-01-16	2700000	paid
1200	33	2023-01-09	cash	2023-01-16	2023-02-16	2700000	paid
1058	27	2022-01-05	cash	2022-01-12	2022-02-12	2200000	paid
1059	27	2022-02-05	cash	2022-02-12	2022-03-12	2200000	paid
1060	27	2022-03-05	cash	2022-03-12	2022-04-12	2200000	paid
1061	27	2022-04-05	cash	2022-04-12	2022-05-12	2200000	paid
1062	27	2022-05-05	cash	2022-05-12	2022-06-12	2200000	paid
1063	27	2022-06-05	cash	2022-06-12	2022-07-12	2200000	paid
1064	27	2022-07-05	cash	2022-07-12	2022-08-12	2200000	paid
1065	27	2022-08-05	cash	2022-08-12	2022-09-12	2200000	paid
1066	27	2022-09-05	cash	2022-09-12	2022-10-12	2200000	paid
1067	27	2022-10-05	cash	2022-10-12	2022-11-12	2200000	paid
1068	27	2022-11-05	cash	2022-11-12	2022-12-12	2200000	paid
1081	28	2018-07-02	cash	2018-07-09	2018-08-09	3300000	paid
1082	28	2018-08-02	cash	2018-08-09	2018-09-09	3300000	paid
1083	28	2018-09-02	cash	2018-09-09	2018-10-09	3300000	paid
1084	28	2018-10-02	cash	2018-10-09	2018-11-09	3300000	paid
1085	28	2018-11-02	cash	2018-11-09	2018-12-09	3300000	paid
1086	28	2018-12-02	cash	2018-12-09	2019-01-09	3300000	paid
1087	28	2019-01-02	cash	2019-01-09	2019-02-09	3300000	paid
1088	28	2019-02-02	cash	2019-02-09	2019-03-09	3300000	paid
1089	28	2019-03-02	cash	2019-03-09	2019-04-09	3300000	paid
1090	28	2019-04-02	cash	2019-04-09	2019-05-09	3300000	paid
1091	28	2019-05-02	cash	2019-05-09	2019-06-09	3300000	paid
1092	28	2019-06-02	cash	2019-06-09	2019-07-09	3300000	paid
1093	28	2019-07-02	cash	2019-07-09	2019-08-09	3300000	paid
1094	28	2019-08-02	cash	2019-08-09	2019-09-09	3300000	paid
1095	28	2019-09-02	cash	2019-09-09	2019-10-09	3300000	paid
1096	28	2019-10-02	cash	2019-10-09	2019-11-09	3300000	paid
1097	28	2019-11-02	cash	2019-11-09	2019-12-09	3300000	paid
1098	28	2019-12-02	cash	2019-12-09	2020-01-09	3300000	paid
1099	28	2020-01-02	cash	2020-01-09	2020-02-09	3300000	paid
1100	28	2020-02-02	cash	2020-02-09	2020-03-09	3300000	paid
1101	28	2020-03-02	cash	2020-03-09	2020-04-09	3300000	paid
1102	28	2020-04-02	cash	2020-04-09	2020-05-09	3300000	paid
1103	28	2020-05-02	cash	2020-05-09	2020-06-09	3300000	paid
1104	28	2020-06-02	cash	2020-06-09	2020-07-09	3300000	paid
1105	28	2020-07-02	cash	2020-07-09	2020-08-09	3300000	paid
1106	28	2020-08-02	cash	2020-08-09	2020-09-09	3300000	paid
1107	28	2020-09-02	cash	2020-09-09	2020-10-09	3300000	paid
1108	28	2020-10-02	cash	2020-10-09	2020-11-09	3300000	paid
1109	28	2020-11-02	cash	2020-11-09	2020-12-09	3300000	paid
1110	28	2020-12-02	cash	2020-12-09	2021-01-09	3300000	paid
1111	28	2021-01-02	cash	2021-01-09	2021-02-09	3300000	paid
1112	28	2021-02-02	cash	2021-02-09	2021-03-09	3300000	paid
1113	28	2021-03-02	cash	2021-03-09	2021-04-09	3300000	paid
1114	28	2021-04-02	cash	2021-04-09	2021-05-09	3300000	paid
1115	28	2021-05-02	cash	2021-05-09	2021-06-09	3300000	paid
1116	28	2021-06-02	cash	2021-06-09	2021-07-09	3300000	paid
1153	30	2020-02-04	cash	2020-02-11	2020-03-11	4600000	paid
1154	30	2020-03-04	cash	2020-03-11	2020-04-11	4600000	paid
1155	30	2020-04-04	cash	2020-04-11	2020-05-11	4600000	paid
1156	30	2020-05-04	cash	2020-05-11	2020-06-11	4600000	paid
1157	30	2020-06-04	cash	2020-06-11	2020-07-11	4600000	paid
1158	30	2020-07-04	cash	2020-07-11	2020-08-11	4600000	paid
1159	30	2020-08-04	cash	2020-08-11	2020-09-11	4600000	paid
1160	30	2020-09-04	cash	2020-09-11	2020-10-11	4600000	paid
1161	30	2020-10-04	cash	2020-10-11	2020-11-11	4600000	paid
1162	30	2020-11-04	cash	2020-11-11	2020-12-11	4600000	paid
1163	30	2020-12-04	cash	2020-12-11	2021-01-11	4600000	paid
1164	30	2021-01-04	cash	2021-01-11	2021-02-11	4600000	paid
1165	31	2018-06-22	cash	2018-06-29	2018-07-29	3300000	paid
1166	31	2018-07-22	cash	2018-07-29	2018-08-29	3300000	paid
1167	31	2018-08-22	cash	2018-08-29	2018-09-29	3300000	paid
1168	31	2018-09-22	cash	2018-09-29	2018-10-29	3300000	paid
1169	31	2018-10-22	cash	2018-10-29	2018-11-29	3300000	paid
1170	31	2018-11-22	cash	2018-11-29	2018-12-29	3300000	paid
1171	31	2018-12-22	cash	2018-12-29	2019-01-29	3300000	paid
1172	31	2019-01-22	cash	2019-01-29	2019-02-28	3300000	paid
1173	31	2019-02-21	cash	2019-02-28	2019-03-28	3300000	paid
1174	31	2019-03-21	cash	2019-03-28	2019-04-28	3300000	paid
1175	31	2019-04-21	cash	2019-04-28	2019-05-28	3300000	paid
1176	31	2019-05-21	cash	2019-05-28	2019-06-28	3300000	paid
1177	32	2021-11-07	cash	2021-11-14	2021-12-14	7400000	paid
1178	32	2021-12-07	cash	2021-12-14	2022-01-14	7400000	paid
1179	32	2022-01-07	cash	2022-01-14	2022-02-14	7400000	paid
1180	32	2022-02-07	cash	2022-02-14	2022-03-14	7400000	paid
1181	32	2022-03-07	cash	2022-03-14	2022-04-14	7400000	paid
1182	32	2022-04-07	cash	2022-04-14	2022-05-14	7400000	paid
1183	32	2022-05-07	cash	2022-05-14	2022-06-14	7400000	paid
1184	32	2022-06-07	cash	2022-06-14	2022-07-14	7400000	paid
1185	32	2022-07-07	cash	2022-07-14	2022-08-14	7400000	paid
1186	32	2022-08-07	cash	2022-08-14	2022-09-14	7400000	paid
1187	32	2022-09-07	cash	2022-09-14	2022-10-14	7400000	paid
1188	32	2022-10-07	cash	2022-10-14	2022-11-14	7400000	paid
1189	33	2022-02-09	cash	2022-02-16	2022-03-16	2700000	paid
1190	33	2022-03-09	cash	2022-03-16	2022-04-16	2700000	paid
1191	33	2022-04-09	cash	2022-04-16	2022-05-16	2700000	paid
1192	33	2022-05-09	cash	2022-05-16	2022-06-16	2700000	paid
1193	33	2022-06-09	cash	2022-06-16	2022-07-16	2700000	paid
1194	33	2022-07-09	cash	2022-07-16	2022-08-16	2700000	paid
1195	33	2022-08-09	cash	2022-08-16	2022-09-16	2700000	paid
1196	33	2022-09-09	cash	2022-09-16	2022-10-16	2700000	paid
1197	33	2022-10-09	cash	2022-10-16	2022-11-16	2700000	paid
1198	33	2022-11-09	cash	2022-11-16	2022-12-16	2700000	paid
1201	34	2020-08-06	cash	2020-08-13	2020-09-13	6100000	paid
1250	35	2022-12-20	cash	2022-12-27	2023-01-27	1400000	paid
1251	35	2023-01-20	cash	2023-01-27	2023-02-27	1400000	paid
1288	36	2022-12-23	cash	2022-12-30	2023-01-30	9800000	paid
1289	36	2023-01-23	cash	2023-01-30	2023-02-28	9800000	paid
1346	37	2022-12-06	cash	2022-12-13	2023-01-13	5200000	paid
1347	37	2023-01-06	cash	2023-01-13	2023-02-13	5200000	paid
1202	34	2020-09-06	cash	2020-09-13	2020-10-13	6100000	paid
1203	34	2020-10-06	cash	2020-10-13	2020-11-13	6100000	paid
1204	34	2020-11-06	cash	2020-11-13	2020-12-13	6100000	paid
1205	34	2020-12-06	cash	2020-12-13	2021-01-13	6100000	paid
1206	34	2021-01-06	cash	2021-01-13	2021-02-13	6100000	paid
1207	34	2021-02-06	cash	2021-02-13	2021-03-13	6100000	paid
1208	34	2021-03-06	cash	2021-03-13	2021-04-13	6100000	paid
1209	34	2021-04-06	cash	2021-04-13	2021-05-13	6100000	paid
1210	34	2021-05-06	cash	2021-05-13	2021-06-13	6100000	paid
1211	34	2021-06-06	cash	2021-06-13	2021-07-13	6100000	paid
1212	34	2021-07-06	cash	2021-07-13	2021-08-13	6100000	paid
1213	34	2021-08-06	cash	2021-08-13	2021-09-13	6100000	paid
1214	34	2021-09-06	cash	2021-09-13	2021-10-13	6100000	paid
1215	34	2021-10-06	cash	2021-10-13	2021-11-13	6100000	paid
1216	34	2021-11-06	cash	2021-11-13	2021-12-13	6100000	paid
1217	34	2021-12-06	cash	2021-12-13	2022-01-13	6100000	paid
1218	34	2022-01-06	cash	2022-01-13	2022-02-13	6100000	paid
1219	34	2022-02-06	cash	2022-02-13	2022-03-13	6100000	paid
1220	34	2022-03-06	cash	2022-03-13	2022-04-13	6100000	paid
1221	34	2022-04-06	cash	2022-04-13	2022-05-13	6100000	paid
1222	34	2022-05-06	cash	2022-05-13	2022-06-13	6100000	paid
1223	34	2022-06-06	cash	2022-06-13	2022-07-13	6100000	paid
1224	34	2022-07-06	cash	2022-07-13	2022-08-13	6100000	paid
1398	38	2022-11-30	cash	2022-12-07	2023-01-07	3600000	paid
1399	38	2022-12-31	cash	2023-01-07	2023-02-07	3600000	paid
1437	39	2022-12-04	cash	2022-12-11	2023-01-11	9700000	paid
1438	39	2023-01-04	cash	2023-01-11	2023-02-11	9700000	paid
1225	35	2020-11-20	cash	2020-11-27	2020-12-27	1400000	paid
1226	35	2020-12-20	cash	2020-12-27	2021-01-27	1400000	paid
1227	35	2021-01-20	cash	2021-01-27	2021-02-27	1400000	paid
1228	35	2021-02-20	cash	2021-02-27	2021-03-27	1400000	paid
1229	35	2021-03-20	cash	2021-03-27	2021-04-27	1400000	paid
1230	35	2021-04-20	cash	2021-04-27	2021-05-27	1400000	paid
1231	35	2021-05-20	cash	2021-05-27	2021-06-27	1400000	paid
1232	35	2021-06-20	cash	2021-06-27	2021-07-27	1400000	paid
1233	35	2021-07-20	cash	2021-07-27	2021-08-27	1400000	paid
1234	35	2021-08-20	cash	2021-08-27	2021-09-27	1400000	paid
1235	35	2021-09-20	cash	2021-09-27	2021-10-27	1400000	paid
1236	35	2021-10-20	cash	2021-10-27	2021-11-27	1400000	paid
1237	35	2021-11-20	cash	2021-11-27	2021-12-27	1400000	paid
1238	35	2021-12-20	cash	2021-12-27	2022-01-27	1400000	paid
1239	35	2022-01-20	cash	2022-01-27	2022-02-27	1400000	paid
1240	35	2022-02-20	cash	2022-02-27	2022-03-27	1400000	paid
1241	35	2022-03-20	cash	2022-03-27	2022-04-27	1400000	paid
1557	42	2022-11-29	cash	2022-12-06	2023-01-06	6500000	paid
1558	42	2022-12-30	cash	2023-01-06	2023-02-06	6500000	paid
1578	43	2022-12-06	cash	2022-12-13	2023-01-13	1400000	paid
1579	43	2023-01-06	cash	2023-01-13	2023-02-13	1400000	paid
1242	35	2022-04-20	cash	2022-04-27	2022-05-27	1400000	paid
1243	35	2022-05-20	cash	2022-05-27	2022-06-27	1400000	paid
1244	35	2022-06-20	cash	2022-06-27	2022-07-27	1400000	paid
1245	35	2022-07-20	cash	2022-07-27	2022-08-27	1400000	paid
1246	35	2022-08-20	cash	2022-08-27	2022-09-27	1400000	paid
1247	35	2022-09-20	cash	2022-09-27	2022-10-27	1400000	paid
1248	35	2022-10-20	cash	2022-10-27	2022-11-27	1400000	paid
1249	35	2022-11-20	cash	2022-11-27	2022-12-27	1400000	paid
1285	36	2022-09-23	cash	2022-09-30	2022-10-30	9800000	paid
1286	36	2022-10-23	cash	2022-10-30	2022-11-30	9800000	paid
1287	36	2022-11-23	cash	2022-11-30	2022-12-30	9800000	paid
1345	37	2022-11-06	cash	2022-11-13	2022-12-13	5200000	paid
1393	38	2022-06-30	cash	2022-07-07	2022-08-07	3600000	paid
1394	38	2022-07-31	cash	2022-08-07	2022-09-07	3600000	paid
1395	38	2022-08-31	cash	2022-09-07	2022-10-07	3600000	paid
1396	38	2022-09-30	cash	2022-10-07	2022-11-07	3600000	paid
1397	38	2022-10-31	cash	2022-11-07	2022-12-07	3600000	paid
1429	39	2022-04-04	cash	2022-04-11	2022-05-11	9700000	paid
1430	39	2022-05-04	cash	2022-05-11	2022-06-11	9700000	paid
1431	39	2022-06-04	cash	2022-06-11	2022-07-11	9700000	paid
1432	39	2022-07-04	cash	2022-07-11	2022-08-11	9700000	paid
1433	39	2022-08-04	cash	2022-08-11	2022-09-11	9700000	paid
1434	39	2022-09-04	cash	2022-09-11	2022-10-11	9700000	paid
1435	39	2022-10-04	cash	2022-10-11	2022-11-11	9700000	paid
1436	39	2022-11-04	cash	2022-11-11	2022-12-11	9700000	paid
1489	40	2018-10-16	cash	2018-10-23	2018-11-23	7200000	paid
1490	40	2018-11-16	cash	2018-11-23	2018-12-23	7200000	paid
1491	40	2018-12-16	cash	2018-12-23	2019-01-23	7200000	paid
1492	40	2019-01-16	cash	2019-01-23	2019-02-23	7200000	paid
1493	40	2019-02-16	cash	2019-02-23	2019-03-23	7200000	paid
1494	40	2019-03-16	cash	2019-03-23	2019-04-23	7200000	paid
1495	40	2019-04-16	cash	2019-04-23	2019-05-23	7200000	paid
1496	40	2019-05-16	cash	2019-05-23	2019-06-23	7200000	paid
1497	40	2019-06-16	cash	2019-06-23	2019-07-23	7200000	paid
1498	40	2019-07-16	cash	2019-07-23	2019-08-23	7200000	paid
1499	40	2019-08-16	cash	2019-08-23	2019-09-23	7200000	paid
1500	40	2019-09-16	cash	2019-09-23	2019-10-23	7200000	paid
1501	40	2019-10-16	cash	2019-10-23	2019-11-23	7200000	paid
1502	40	2019-11-16	cash	2019-11-23	2019-12-23	7200000	paid
1503	40	2019-12-16	cash	2019-12-23	2020-01-23	7200000	paid
1504	40	2020-01-16	cash	2020-01-23	2020-02-23	7200000	paid
1505	40	2020-02-16	cash	2020-02-23	2020-03-23	7200000	paid
1506	40	2020-03-16	cash	2020-03-23	2020-04-23	7200000	paid
1507	40	2020-04-16	cash	2020-04-23	2020-05-23	7200000	paid
1508	40	2020-05-16	cash	2020-05-23	2020-06-23	7200000	paid
1509	40	2020-06-16	cash	2020-06-23	2020-07-23	7200000	paid
1510	40	2020-07-16	cash	2020-07-23	2020-08-23	7200000	paid
1511	40	2020-08-16	cash	2020-08-23	2020-09-23	7200000	paid
1512	40	2020-09-16	cash	2020-09-23	2020-10-23	7200000	paid
1513	40	2020-10-16	cash	2020-10-23	2020-11-23	7200000	paid
1514	40	2020-11-16	cash	2020-11-23	2020-12-23	7200000	paid
1515	40	2020-12-16	cash	2020-12-23	2021-01-23	7200000	paid
1516	40	2021-01-16	cash	2021-01-23	2021-02-23	7200000	paid
1517	40	2021-02-16	cash	2021-02-23	2021-03-23	7200000	paid
1518	40	2021-03-16	cash	2021-03-23	2021-04-23	7200000	paid
1519	40	2021-04-16	cash	2021-04-23	2021-05-23	7200000	paid
1520	40	2021-05-16	cash	2021-05-23	2021-06-23	7200000	paid
1521	40	2021-06-16	cash	2021-06-23	2021-07-23	7200000	paid
1522	40	2021-07-16	cash	2021-07-23	2021-08-23	7200000	paid
1523	40	2021-08-16	cash	2021-08-23	2021-09-23	7200000	paid
1524	40	2021-09-16	cash	2021-09-23	2021-10-23	7200000	paid
1525	41	2018-05-01	cash	2018-05-08	2018-06-08	3500000	paid
1526	41	2018-06-01	cash	2018-06-08	2018-07-08	3500000	paid
1527	41	2018-07-01	cash	2018-07-08	2018-08-08	3500000	paid
1528	41	2018-08-01	cash	2018-08-08	2018-09-08	3500000	paid
1529	41	2018-09-01	cash	2018-09-08	2018-10-08	3500000	paid
1530	41	2018-10-01	cash	2018-10-08	2018-11-08	3500000	paid
1531	41	2018-11-01	cash	2018-11-08	2018-12-08	3500000	paid
1532	41	2018-12-01	cash	2018-12-08	2019-01-08	3500000	paid
1533	41	2019-01-01	cash	2019-01-08	2019-02-08	3500000	paid
1534	41	2019-02-01	cash	2019-02-08	2019-03-08	3500000	paid
1535	41	2019-03-01	cash	2019-03-08	2019-04-08	3500000	paid
1536	41	2019-04-01	cash	2019-04-08	2019-05-08	3500000	paid
1537	41	2019-05-01	cash	2019-05-08	2019-06-08	3500000	paid
1538	41	2019-06-01	cash	2019-06-08	2019-07-08	3500000	paid
1539	41	2019-07-01	cash	2019-07-08	2019-08-08	3500000	paid
1540	41	2019-08-01	cash	2019-08-08	2019-09-08	3500000	paid
1541	41	2019-09-01	cash	2019-09-08	2019-10-08	3500000	paid
1542	41	2019-10-01	cash	2019-10-08	2019-11-08	3500000	paid
1543	41	2019-11-01	cash	2019-11-08	2019-12-08	3500000	paid
1544	41	2019-12-01	cash	2019-12-08	2020-01-08	3500000	paid
1545	41	2020-01-01	cash	2020-01-08	2020-02-08	3500000	paid
1546	41	2020-02-01	cash	2020-02-08	2020-03-08	3500000	paid
1547	41	2020-03-01	cash	2020-03-08	2020-04-08	3500000	paid
1548	41	2020-04-01	cash	2020-04-08	2020-05-08	3500000	paid
1549	42	2022-03-30	cash	2022-04-06	2022-05-06	6500000	paid
1550	42	2022-04-29	cash	2022-05-06	2022-06-06	6500000	paid
1551	42	2022-05-30	cash	2022-06-06	2022-07-06	6500000	paid
1552	42	2022-06-29	cash	2022-07-06	2022-08-06	6500000	paid
1553	42	2022-07-30	cash	2022-08-06	2022-09-06	6500000	paid
1554	42	2022-08-30	cash	2022-09-06	2022-10-06	6500000	paid
1555	42	2022-09-29	cash	2022-10-06	2022-11-06	6500000	paid
1556	42	2022-10-30	cash	2022-11-06	2022-12-06	6500000	paid
1561	43	2021-07-06	cash	2021-07-13	2021-08-13	1400000	paid
1562	43	2021-08-06	cash	2021-08-13	2021-09-13	1400000	paid
1563	43	2021-09-06	cash	2021-09-13	2021-10-13	1400000	paid
1564	43	2021-10-06	cash	2021-10-13	2021-11-13	1400000	paid
1654	44	2022-11-28	cash	2022-12-05	2023-01-05	3200000	paid
1655	44	2022-12-29	cash	2023-01-05	2023-02-05	3200000	paid
1703	45	2022-12-12	cash	2022-12-19	2023-01-19	7300000	paid
1704	45	2023-01-12	cash	2023-01-19	2023-02-19	7300000	paid
1765	46	2022-12-07	cash	2022-12-14	2023-01-14	8000000	paid
1766	46	2023-01-07	cash	2023-01-14	2023-02-14	8000000	paid
1565	43	2021-11-06	cash	2021-11-13	2021-12-13	1400000	paid
1566	43	2021-12-06	cash	2021-12-13	2022-01-13	1400000	paid
1567	43	2022-01-06	cash	2022-01-13	2022-02-13	1400000	paid
1568	43	2022-02-06	cash	2022-02-13	2022-03-13	1400000	paid
1569	43	2022-03-06	cash	2022-03-13	2022-04-13	1400000	paid
1570	43	2022-04-06	cash	2022-04-13	2022-05-13	1400000	paid
1571	43	2022-05-06	cash	2022-05-13	2022-06-13	1400000	paid
1572	43	2022-06-06	cash	2022-06-13	2022-07-13	1400000	paid
1573	43	2022-07-06	cash	2022-07-13	2022-08-13	1400000	paid
1574	43	2022-08-06	cash	2022-08-13	2022-09-13	1400000	paid
1575	43	2022-09-06	cash	2022-09-13	2022-10-13	1400000	paid
1576	43	2022-10-06	cash	2022-10-13	2022-11-13	1400000	paid
1577	43	2022-11-06	cash	2022-11-13	2022-12-13	1400000	paid
1609	44	2019-02-26	cash	2019-03-05	2019-04-05	3200000	paid
1610	44	2019-03-29	cash	2019-04-05	2019-05-05	3200000	paid
1611	44	2019-04-28	cash	2019-05-05	2019-06-05	3200000	paid
1612	44	2019-05-29	cash	2019-06-05	2019-07-05	3200000	paid
1613	44	2019-06-28	cash	2019-07-05	2019-08-05	3200000	paid
1614	44	2019-07-29	cash	2019-08-05	2019-09-05	3200000	paid
1615	44	2019-08-29	cash	2019-09-05	2019-10-05	3200000	paid
1616	44	2019-09-28	cash	2019-10-05	2019-11-05	3200000	paid
1617	44	2019-10-29	cash	2019-11-05	2019-12-05	3200000	paid
1618	44	2019-11-28	cash	2019-12-05	2020-01-05	3200000	paid
1619	44	2019-12-29	cash	2020-01-05	2020-02-05	3200000	paid
1620	44	2020-01-29	cash	2020-02-05	2020-03-05	3200000	paid
1621	44	2020-02-27	cash	2020-03-05	2020-04-05	3200000	paid
1622	44	2020-03-29	cash	2020-04-05	2020-05-05	3200000	paid
1623	44	2020-04-28	cash	2020-05-05	2020-06-05	3200000	paid
1624	44	2020-05-29	cash	2020-06-05	2020-07-05	3200000	paid
1625	44	2020-06-28	cash	2020-07-05	2020-08-05	3200000	paid
1626	44	2020-07-29	cash	2020-08-05	2020-09-05	3200000	paid
1627	44	2020-08-29	cash	2020-09-05	2020-10-05	3200000	paid
1628	44	2020-09-28	cash	2020-10-05	2020-11-05	3200000	paid
1629	44	2020-10-29	cash	2020-11-05	2020-12-05	3200000	paid
1630	44	2020-11-28	cash	2020-12-05	2021-01-05	3200000	paid
1631	44	2020-12-29	cash	2021-01-05	2021-02-05	3200000	paid
1632	44	2021-01-29	cash	2021-02-05	2021-03-05	3200000	paid
1633	44	2021-02-26	cash	2021-03-05	2021-04-05	3200000	paid
1634	44	2021-03-29	cash	2021-04-05	2021-05-05	3200000	paid
1635	44	2021-04-28	cash	2021-05-05	2021-06-05	3200000	paid
1636	44	2021-05-29	cash	2021-06-05	2021-07-05	3200000	paid
1637	44	2021-06-28	cash	2021-07-05	2021-08-05	3200000	paid
1638	44	2021-07-29	cash	2021-08-05	2021-09-05	3200000	paid
1639	44	2021-08-29	cash	2021-09-05	2021-10-05	3200000	paid
1640	44	2021-09-28	cash	2021-10-05	2021-11-05	3200000	paid
1641	44	2021-10-29	cash	2021-11-05	2021-12-05	3200000	paid
1642	44	2021-11-28	cash	2021-12-05	2022-01-05	3200000	paid
1643	44	2021-12-29	cash	2022-01-05	2022-02-05	3200000	paid
1644	44	2022-01-29	cash	2022-02-05	2022-03-05	3200000	paid
1645	44	2022-02-26	cash	2022-03-05	2022-04-05	3200000	paid
1646	44	2022-03-29	cash	2022-04-05	2022-05-05	3200000	paid
1647	44	2022-04-28	cash	2022-05-05	2022-06-05	3200000	paid
1648	44	2022-05-29	cash	2022-06-05	2022-07-05	3200000	paid
1649	44	2022-06-28	cash	2022-07-05	2022-08-05	3200000	paid
1650	44	2022-07-29	cash	2022-08-05	2022-09-05	3200000	paid
1651	44	2022-08-29	cash	2022-09-05	2022-10-05	3200000	paid
1652	44	2022-09-28	cash	2022-10-05	2022-11-05	3200000	paid
1653	44	2022-10-29	cash	2022-11-05	2022-12-05	3200000	paid
1669	45	2020-02-12	cash	2020-02-19	2020-03-19	7300000	paid
1670	45	2020-03-12	cash	2020-03-19	2020-04-19	7300000	paid
1671	45	2020-04-12	cash	2020-04-19	2020-05-19	7300000	paid
1672	45	2020-05-12	cash	2020-05-19	2020-06-19	7300000	paid
1673	45	2020-06-12	cash	2020-06-19	2020-07-19	7300000	paid
1674	45	2020-07-12	cash	2020-07-19	2020-08-19	7300000	paid
1675	45	2020-08-12	cash	2020-08-19	2020-09-19	7300000	paid
1676	45	2020-09-12	cash	2020-09-19	2020-10-19	7300000	paid
1677	45	2020-10-12	cash	2020-10-19	2020-11-19	7300000	paid
1678	45	2020-11-12	cash	2020-11-19	2020-12-19	7300000	paid
1679	45	2020-12-12	cash	2020-12-19	2021-01-19	7300000	paid
1680	45	2021-01-12	cash	2021-01-19	2021-02-19	7300000	paid
1681	45	2021-02-12	cash	2021-02-19	2021-03-19	7300000	paid
1682	45	2021-03-12	cash	2021-03-19	2021-04-19	7300000	paid
1683	45	2021-04-12	cash	2021-04-19	2021-05-19	7300000	paid
1684	45	2021-05-12	cash	2021-05-19	2021-06-19	7300000	paid
1685	45	2021-06-12	cash	2021-06-19	2021-07-19	7300000	paid
1686	45	2021-07-12	cash	2021-07-19	2021-08-19	7300000	paid
1687	45	2021-08-12	cash	2021-08-19	2021-09-19	7300000	paid
1688	45	2021-09-12	cash	2021-09-19	2021-10-19	7300000	paid
1689	45	2021-10-12	cash	2021-10-19	2021-11-19	7300000	paid
1690	45	2021-11-12	cash	2021-11-19	2021-12-19	7300000	paid
1691	45	2021-12-12	cash	2021-12-19	2022-01-19	7300000	paid
1692	45	2022-01-12	cash	2022-01-19	2022-02-19	7300000	paid
1693	45	2022-02-12	cash	2022-02-19	2022-03-19	7300000	paid
1694	45	2022-03-12	cash	2022-03-19	2022-04-19	7300000	paid
1695	45	2022-04-12	cash	2022-04-19	2022-05-19	7300000	paid
1825	47	2022-12-08	cash	2022-12-15	2023-01-15	4200000	paid
1826	47	2023-01-08	cash	2023-01-15	2023-02-15	4200000	paid
1873	49	2022-12-09	cash	2022-12-16	2023-01-16	6600000	paid
1874	49	2023-01-09	cash	2023-01-16	2023-02-16	6600000	paid
1696	45	2022-05-12	cash	2022-05-19	2022-06-19	7300000	paid
1697	45	2022-06-12	cash	2022-06-19	2022-07-19	7300000	paid
1698	45	2022-07-12	cash	2022-07-19	2022-08-19	7300000	paid
1699	45	2022-08-12	cash	2022-08-19	2022-09-19	7300000	paid
1700	45	2022-09-12	cash	2022-09-19	2022-10-19	7300000	paid
1701	45	2022-10-12	cash	2022-10-19	2022-11-19	7300000	paid
1702	45	2022-11-12	cash	2022-11-19	2022-12-19	7300000	paid
1729	46	2019-12-07	cash	2019-12-14	2020-01-14	8000000	paid
1730	46	2020-01-07	cash	2020-01-14	2020-02-14	8000000	paid
1731	46	2020-02-07	cash	2020-02-14	2020-03-14	8000000	paid
1732	46	2020-03-07	cash	2020-03-14	2020-04-14	8000000	paid
1733	46	2020-04-07	cash	2020-04-14	2020-05-14	8000000	paid
1734	46	2020-05-07	cash	2020-05-14	2020-06-14	8000000	paid
1735	46	2020-06-07	cash	2020-06-14	2020-07-14	8000000	paid
1736	46	2020-07-07	cash	2020-07-14	2020-08-14	8000000	paid
1737	46	2020-08-07	cash	2020-08-14	2020-09-14	8000000	paid
1738	46	2020-09-07	cash	2020-09-14	2020-10-14	8000000	paid
1739	46	2020-10-07	cash	2020-10-14	2020-11-14	8000000	paid
1740	46	2020-11-07	cash	2020-11-14	2020-12-14	8000000	paid
1741	46	2020-12-07	cash	2020-12-14	2021-01-14	8000000	paid
1742	46	2021-01-07	cash	2021-01-14	2021-02-14	8000000	paid
1743	46	2021-02-07	cash	2021-02-14	2021-03-14	8000000	paid
1744	46	2021-03-07	cash	2021-03-14	2021-04-14	8000000	paid
1745	46	2021-04-07	cash	2021-04-14	2021-05-14	8000000	paid
1746	46	2021-05-07	cash	2021-05-14	2021-06-14	8000000	paid
1747	46	2021-06-07	cash	2021-06-14	2021-07-14	8000000	paid
1748	46	2021-07-07	cash	2021-07-14	2021-08-14	8000000	paid
1749	46	2021-08-07	cash	2021-08-14	2021-09-14	8000000	paid
1750	46	2021-09-07	cash	2021-09-14	2021-10-14	8000000	paid
1751	46	2021-10-07	cash	2021-10-14	2021-11-14	8000000	paid
1752	46	2021-11-07	cash	2021-11-14	2021-12-14	8000000	paid
1753	46	2021-12-07	cash	2021-12-14	2022-01-14	8000000	paid
1754	46	2022-01-07	cash	2022-01-14	2022-02-14	8000000	paid
1755	46	2022-02-07	cash	2022-02-14	2022-03-14	8000000	paid
1756	46	2022-03-07	cash	2022-03-14	2022-04-14	8000000	paid
1757	46	2022-04-07	cash	2022-04-14	2022-05-14	8000000	paid
1758	46	2022-05-07	cash	2022-05-14	2022-06-14	8000000	paid
1759	46	2022-06-07	cash	2022-06-14	2022-07-14	8000000	paid
1760	46	2022-07-07	cash	2022-07-14	2022-08-14	8000000	paid
1761	46	2022-08-07	cash	2022-08-14	2022-09-14	8000000	paid
1762	46	2022-09-07	cash	2022-09-14	2022-10-14	8000000	paid
1763	46	2022-10-07	cash	2022-10-14	2022-11-14	8000000	paid
1764	46	2022-11-07	cash	2022-11-14	2022-12-14	8000000	paid
1789	47	2019-12-08	cash	2019-12-15	2020-01-15	4200000	paid
1790	47	2020-01-08	cash	2020-01-15	2020-02-15	4200000	paid
1791	47	2020-02-08	cash	2020-02-15	2020-03-15	4200000	paid
1792	47	2020-03-08	cash	2020-03-15	2020-04-15	4200000	paid
1793	47	2020-04-08	cash	2020-04-15	2020-05-15	4200000	paid
1794	47	2020-05-08	cash	2020-05-15	2020-06-15	4200000	paid
1795	47	2020-06-08	cash	2020-06-15	2020-07-15	4200000	paid
1796	47	2020-07-08	cash	2020-07-15	2020-08-15	4200000	paid
1797	47	2020-08-08	cash	2020-08-15	2020-09-15	4200000	paid
1798	47	2020-09-08	cash	2020-09-15	2020-10-15	4200000	paid
1799	47	2020-10-08	cash	2020-10-15	2020-11-15	4200000	paid
1800	47	2020-11-08	cash	2020-11-15	2020-12-15	4200000	paid
1801	47	2020-12-08	cash	2020-12-15	2021-01-15	4200000	paid
1802	47	2021-01-08	cash	2021-01-15	2021-02-15	4200000	paid
1803	47	2021-02-08	cash	2021-02-15	2021-03-15	4200000	paid
1804	47	2021-03-08	cash	2021-03-15	2021-04-15	4200000	paid
1805	47	2021-04-08	cash	2021-04-15	2021-05-15	4200000	paid
1806	47	2021-05-08	cash	2021-05-15	2021-06-15	4200000	paid
1807	47	2021-06-08	cash	2021-06-15	2021-07-15	4200000	paid
1808	47	2021-07-08	cash	2021-07-15	2021-08-15	4200000	paid
1809	47	2021-08-08	cash	2021-08-15	2021-09-15	4200000	paid
1810	47	2021-09-08	cash	2021-09-15	2021-10-15	4200000	paid
1811	47	2021-10-08	cash	2021-10-15	2021-11-15	4200000	paid
1812	47	2021-11-08	cash	2021-11-15	2021-12-15	4200000	paid
1813	47	2021-12-08	cash	2021-12-15	2022-01-15	4200000	paid
2000	53	2022-11-27	cash	2022-12-04	2023-01-04	5300000	paid
2001	53	2022-12-28	cash	2023-01-04	2023-02-04	5300000	paid
1814	47	2022-01-08	cash	2022-01-15	2022-02-15	4200000	paid
1815	47	2022-02-08	cash	2022-02-15	2022-03-15	4200000	paid
1816	47	2022-03-08	cash	2022-03-15	2022-04-15	4200000	paid
1817	47	2022-04-08	cash	2022-04-15	2022-05-15	4200000	paid
1818	47	2022-05-08	cash	2022-05-15	2022-06-15	4200000	paid
1819	47	2022-06-08	cash	2022-06-15	2022-07-15	4200000	paid
1820	47	2022-07-08	cash	2022-07-15	2022-08-15	4200000	paid
1821	47	2022-08-08	cash	2022-08-15	2022-09-15	4200000	paid
1822	47	2022-09-08	cash	2022-09-15	2022-10-15	4200000	paid
1823	47	2022-10-08	cash	2022-10-15	2022-11-15	4200000	paid
1824	47	2022-11-08	cash	2022-11-15	2022-12-15	4200000	paid
1837	48	2019-01-08	cash	2019-01-15	2019-02-15	5400000	paid
1838	48	2019-02-08	cash	2019-02-15	2019-03-15	5400000	paid
1839	48	2019-03-08	cash	2019-03-15	2019-04-15	5400000	paid
1840	48	2019-04-08	cash	2019-04-15	2019-05-15	5400000	paid
1841	48	2019-05-08	cash	2019-05-15	2019-06-15	5400000	paid
1842	48	2019-06-08	cash	2019-06-15	2019-07-15	5400000	paid
1843	48	2019-07-08	cash	2019-07-15	2019-08-15	5400000	paid
1844	48	2019-08-08	cash	2019-08-15	2019-09-15	5400000	paid
1845	48	2019-09-08	cash	2019-09-15	2019-10-15	5400000	paid
1846	48	2019-10-08	cash	2019-10-15	2019-11-15	5400000	paid
1847	48	2019-11-08	cash	2019-11-15	2019-12-15	5400000	paid
1848	48	2019-12-08	cash	2019-12-15	2020-01-15	5400000	paid
1849	48	2020-01-08	cash	2020-01-15	2020-02-15	5400000	paid
1850	48	2020-02-08	cash	2020-02-15	2020-03-15	5400000	paid
1851	48	2020-03-08	cash	2020-03-15	2020-04-15	5400000	paid
1852	48	2020-04-08	cash	2020-04-15	2020-05-15	5400000	paid
1853	48	2020-05-08	cash	2020-05-15	2020-06-15	5400000	paid
1854	48	2020-06-08	cash	2020-06-15	2020-07-15	5400000	paid
1855	48	2020-07-08	cash	2020-07-15	2020-08-15	5400000	paid
1856	48	2020-08-08	cash	2020-08-15	2020-09-15	5400000	paid
1857	48	2020-09-08	cash	2020-09-15	2020-10-15	5400000	paid
1858	48	2020-10-08	cash	2020-10-15	2020-11-15	5400000	paid
1859	48	2020-11-08	cash	2020-11-15	2020-12-15	5400000	paid
1860	48	2020-12-08	cash	2020-12-15	2021-01-15	5400000	paid
1861	49	2021-12-09	cash	2021-12-16	2022-01-16	6600000	paid
1862	49	2022-01-09	cash	2022-01-16	2022-02-16	6600000	paid
1863	49	2022-02-09	cash	2022-02-16	2022-03-16	6600000	paid
1864	49	2022-03-09	cash	2022-03-16	2022-04-16	6600000	paid
1865	49	2022-04-09	cash	2022-04-16	2022-05-16	6600000	paid
1866	49	2022-05-09	cash	2022-05-16	2022-06-16	6600000	paid
1867	49	2022-06-09	cash	2022-06-16	2022-07-16	6600000	paid
1868	49	2022-07-09	cash	2022-07-16	2022-08-16	6600000	paid
1869	49	2022-08-09	cash	2022-08-16	2022-09-16	6600000	paid
1870	49	2022-09-09	cash	2022-09-16	2022-10-16	6600000	paid
1871	49	2022-10-09	cash	2022-10-16	2022-11-16	6600000	paid
1872	49	2022-11-09	cash	2022-11-16	2022-12-16	6600000	paid
1909	50	2019-01-17	cash	2019-01-24	2019-02-24	4800000	paid
1910	50	2019-02-17	cash	2019-02-24	2019-03-24	4800000	paid
1911	50	2019-03-17	cash	2019-03-24	2019-04-24	4800000	paid
1912	50	2019-04-17	cash	2019-04-24	2019-05-24	4800000	paid
1913	50	2019-05-17	cash	2019-05-24	2019-06-24	4800000	paid
1914	50	2019-06-17	cash	2019-06-24	2019-07-24	4800000	paid
1915	50	2019-07-17	cash	2019-07-24	2019-08-24	4800000	paid
1916	50	2019-08-17	cash	2019-08-24	2019-09-24	4800000	paid
1917	50	2019-09-17	cash	2019-09-24	2019-10-24	4800000	paid
1918	50	2019-10-17	cash	2019-10-24	2019-11-24	4800000	paid
1919	50	2019-11-17	cash	2019-11-24	2019-12-24	4800000	paid
1920	50	2019-12-17	cash	2019-12-24	2020-01-24	4800000	paid
1921	50	2020-01-17	cash	2020-01-24	2020-02-24	4800000	paid
1922	50	2020-02-17	cash	2020-02-24	2020-03-24	4800000	paid
1923	50	2020-03-17	cash	2020-03-24	2020-04-24	4800000	paid
1924	50	2020-04-17	cash	2020-04-24	2020-05-24	4800000	paid
1925	50	2020-05-17	cash	2020-05-24	2020-06-24	4800000	paid
1926	50	2020-06-17	cash	2020-06-24	2020-07-24	4800000	paid
1927	50	2020-07-17	cash	2020-07-24	2020-08-24	4800000	paid
1928	50	2020-08-17	cash	2020-08-24	2020-09-24	4800000	paid
1929	50	2020-09-17	cash	2020-09-24	2020-10-24	4800000	paid
1930	50	2020-10-17	cash	2020-10-24	2020-11-24	4800000	paid
1931	50	2020-11-17	cash	2020-11-24	2020-12-24	4800000	paid
1932	50	2020-12-17	cash	2020-12-24	2021-01-24	4800000	paid
1933	51	2018-05-26	cash	2018-06-02	2018-07-02	8400000	paid
1934	51	2018-06-25	cash	2018-07-02	2018-08-02	8400000	paid
1935	51	2018-07-26	cash	2018-08-02	2018-09-02	8400000	paid
1936	51	2018-08-26	cash	2018-09-02	2018-10-02	8400000	paid
1937	51	2018-09-25	cash	2018-10-02	2018-11-02	8400000	paid
1938	51	2018-10-26	cash	2018-11-02	2018-12-02	8400000	paid
1939	51	2018-11-25	cash	2018-12-02	2019-01-02	8400000	paid
1940	51	2018-12-26	cash	2019-01-02	2019-02-02	8400000	paid
1941	51	2019-01-26	cash	2019-02-02	2019-03-02	8400000	paid
1942	51	2019-02-23	cash	2019-03-02	2019-04-02	8400000	paid
1943	51	2019-03-26	cash	2019-04-02	2019-05-02	8400000	paid
1944	51	2019-04-25	cash	2019-05-02	2019-06-02	8400000	paid
1945	51	2019-05-26	cash	2019-06-02	2019-07-02	8400000	paid
1946	51	2019-06-25	cash	2019-07-02	2019-08-02	8400000	paid
1947	51	2019-07-26	cash	2019-08-02	2019-09-02	8400000	paid
1948	51	2019-08-26	cash	2019-09-02	2019-10-02	8400000	paid
1949	51	2019-09-25	cash	2019-10-02	2019-11-02	8400000	paid
1950	51	2019-10-26	cash	2019-11-02	2019-12-02	8400000	paid
2061	54	2022-12-12	cash	2022-12-19	2023-01-19	1400000	paid
2062	54	2023-01-12	cash	2023-01-19	2023-02-19	1400000	paid
2108	55	2022-12-05	cash	2022-12-12	2023-01-12	7500000	paid
2109	55	2023-01-05	cash	2023-01-12	2023-02-12	7500000	paid
2160	56	2022-12-21	cash	2022-12-28	2023-01-28	3500000	paid
2161	56	2023-01-21	cash	2023-01-28	2023-02-28	3500000	paid
1951	51	2019-11-25	cash	2019-12-02	2020-01-02	8400000	paid
1952	51	2019-12-26	cash	2020-01-02	2020-02-02	8400000	paid
1953	51	2020-01-26	cash	2020-02-02	2020-03-02	8400000	paid
1954	51	2020-02-24	cash	2020-03-02	2020-04-02	8400000	paid
1955	51	2020-03-26	cash	2020-04-02	2020-05-02	8400000	paid
1956	51	2020-04-25	cash	2020-05-02	2020-06-02	8400000	paid
1957	51	2020-05-26	cash	2020-06-02	2020-07-02	8400000	paid
1958	51	2020-06-25	cash	2020-07-02	2020-08-02	8400000	paid
1959	51	2020-07-26	cash	2020-08-02	2020-09-02	8400000	paid
1960	51	2020-08-26	cash	2020-09-02	2020-10-02	8400000	paid
1961	51	2020-09-25	cash	2020-10-02	2020-11-02	8400000	paid
1962	51	2020-10-26	cash	2020-11-02	2020-12-02	8400000	paid
1963	51	2020-11-25	cash	2020-12-02	2021-01-02	8400000	paid
1964	51	2020-12-26	cash	2021-01-02	2021-02-02	8400000	paid
1965	51	2021-01-26	cash	2021-02-02	2021-03-02	8400000	paid
1966	51	2021-02-23	cash	2021-03-02	2021-04-02	8400000	paid
1967	51	2021-03-26	cash	2021-04-02	2021-05-02	8400000	paid
1968	51	2021-04-25	cash	2021-05-02	2021-06-02	8400000	paid
1969	51	2021-05-26	cash	2021-06-02	2021-07-02	8400000	paid
1970	51	2021-06-25	cash	2021-07-02	2021-08-02	8400000	paid
1971	51	2021-07-26	cash	2021-08-02	2021-09-02	8400000	paid
1972	51	2021-08-26	cash	2021-09-02	2021-10-02	8400000	paid
1973	51	2021-09-25	cash	2021-10-02	2021-11-02	8400000	paid
1974	51	2021-10-26	cash	2021-11-02	2021-12-02	8400000	paid
1975	51	2021-11-25	cash	2021-12-02	2022-01-02	8400000	paid
1976	51	2021-12-26	cash	2022-01-02	2022-02-02	8400000	paid
1977	51	2022-01-26	cash	2022-02-02	2022-03-02	8400000	paid
1978	51	2022-02-23	cash	2022-03-02	2022-04-02	8400000	paid
1979	51	2022-03-26	cash	2022-04-02	2022-05-02	8400000	paid
1980	51	2022-04-25	cash	2022-05-02	2022-06-02	8400000	paid
1981	52	2020-06-16	cash	2020-06-23	2020-07-23	5800000	paid
1982	52	2020-07-16	cash	2020-07-23	2020-08-23	5800000	paid
1983	52	2020-08-16	cash	2020-08-23	2020-09-23	5800000	paid
1984	52	2020-09-16	cash	2020-09-23	2020-10-23	5800000	paid
1985	52	2020-10-16	cash	2020-10-23	2020-11-23	5800000	paid
1986	52	2020-11-16	cash	2020-11-23	2020-12-23	5800000	paid
1987	52	2020-12-16	cash	2020-12-23	2021-01-23	5800000	paid
1988	52	2021-01-16	cash	2021-01-23	2021-02-23	5800000	paid
1989	52	2021-02-16	cash	2021-02-23	2021-03-23	5800000	paid
1990	52	2021-03-16	cash	2021-03-23	2021-04-23	5800000	paid
1991	52	2021-04-16	cash	2021-04-23	2021-05-23	5800000	paid
1992	52	2021-05-16	cash	2021-05-23	2021-06-23	5800000	paid
1993	53	2022-04-27	cash	2022-05-04	2022-06-04	5300000	paid
1994	53	2022-05-28	cash	2022-06-04	2022-07-04	5300000	paid
1995	53	2022-06-27	cash	2022-07-04	2022-08-04	5300000	paid
1996	53	2022-07-28	cash	2022-08-04	2022-09-04	5300000	paid
1997	53	2022-08-28	cash	2022-09-04	2022-10-04	5300000	paid
1998	53	2022-09-27	cash	2022-10-04	2022-11-04	5300000	paid
1999	53	2022-10-28	cash	2022-11-04	2022-12-04	5300000	paid
2053	54	2022-04-12	cash	2022-04-19	2022-05-19	1400000	paid
2054	54	2022-05-12	cash	2022-05-19	2022-06-19	1400000	paid
2055	54	2022-06-12	cash	2022-06-19	2022-07-19	1400000	paid
2056	54	2022-07-12	cash	2022-07-19	2022-08-19	1400000	paid
2057	54	2022-08-12	cash	2022-08-19	2022-09-19	1400000	paid
2058	54	2022-09-12	cash	2022-09-19	2022-10-19	1400000	paid
2059	54	2022-10-12	cash	2022-10-19	2022-11-19	1400000	paid
2060	54	2022-11-12	cash	2022-11-19	2022-12-19	1400000	paid
2077	55	2020-05-05	cash	2020-05-12	2020-06-12	7500000	paid
2078	55	2020-06-05	cash	2020-06-12	2020-07-12	7500000	paid
2079	55	2020-07-05	cash	2020-07-12	2020-08-12	7500000	paid
2189	57	2022-12-11	cash	2022-12-18	2023-01-18	1400000	paid
2190	57	2023-01-11	cash	2023-01-18	2023-02-18	1400000	paid
2252	58	2022-12-11	cash	2022-12-18	2023-01-18	9600000	paid
2253	58	2023-01-11	cash	2023-01-18	2023-02-18	9600000	paid
2080	55	2020-08-05	cash	2020-08-12	2020-09-12	7500000	paid
2081	55	2020-09-05	cash	2020-09-12	2020-10-12	7500000	paid
2082	55	2020-10-05	cash	2020-10-12	2020-11-12	7500000	paid
2083	55	2020-11-05	cash	2020-11-12	2020-12-12	7500000	paid
2084	55	2020-12-05	cash	2020-12-12	2021-01-12	7500000	paid
2085	55	2021-01-05	cash	2021-01-12	2021-02-12	7500000	paid
2086	55	2021-02-05	cash	2021-02-12	2021-03-12	7500000	paid
2087	55	2021-03-05	cash	2021-03-12	2021-04-12	7500000	paid
2088	55	2021-04-05	cash	2021-04-12	2021-05-12	7500000	paid
2089	55	2021-05-05	cash	2021-05-12	2021-06-12	7500000	paid
2090	55	2021-06-05	cash	2021-06-12	2021-07-12	7500000	paid
2091	55	2021-07-05	cash	2021-07-12	2021-08-12	7500000	paid
2092	55	2021-08-05	cash	2021-08-12	2021-09-12	7500000	paid
2093	55	2021-09-05	cash	2021-09-12	2021-10-12	7500000	paid
2094	55	2021-10-05	cash	2021-10-12	2021-11-12	7500000	paid
2095	55	2021-11-05	cash	2021-11-12	2021-12-12	7500000	paid
2096	55	2021-12-05	cash	2021-12-12	2022-01-12	7500000	paid
2097	55	2022-01-05	cash	2022-01-12	2022-02-12	7500000	paid
2098	55	2022-02-05	cash	2022-02-12	2022-03-12	7500000	paid
2099	55	2022-03-05	cash	2022-03-12	2022-04-12	7500000	paid
2100	55	2022-04-05	cash	2022-04-12	2022-05-12	7500000	paid
2101	55	2022-05-05	cash	2022-05-12	2022-06-12	7500000	paid
2102	55	2022-06-05	cash	2022-06-12	2022-07-12	7500000	paid
2103	55	2022-07-05	cash	2022-07-12	2022-08-12	7500000	paid
2104	55	2022-08-05	cash	2022-08-12	2022-09-12	7500000	paid
2105	55	2022-09-05	cash	2022-09-12	2022-10-12	7500000	paid
2106	55	2022-10-05	cash	2022-10-12	2022-11-12	7500000	paid
2107	55	2022-11-05	cash	2022-11-12	2022-12-12	7500000	paid
2137	56	2021-01-22	cash	2021-01-29	2021-02-28	3500000	paid
2138	56	2021-02-21	cash	2021-02-28	2021-03-28	3500000	paid
2139	56	2021-03-21	cash	2021-03-28	2021-04-28	3500000	paid
2140	56	2021-04-21	cash	2021-04-28	2021-05-28	3500000	paid
2141	56	2021-05-21	cash	2021-05-28	2021-06-28	3500000	paid
2142	56	2021-06-21	cash	2021-06-28	2021-07-28	3500000	paid
2143	56	2021-07-21	cash	2021-07-28	2021-08-28	3500000	paid
2144	56	2021-08-21	cash	2021-08-28	2021-09-28	3500000	paid
2145	56	2021-09-21	cash	2021-09-28	2021-10-28	3500000	paid
2146	56	2021-10-21	cash	2021-10-28	2021-11-28	3500000	paid
2147	56	2021-11-21	cash	2021-11-28	2021-12-28	3500000	paid
2148	56	2021-12-21	cash	2021-12-28	2022-01-28	3500000	paid
2149	56	2022-01-21	cash	2022-01-28	2022-02-28	3500000	paid
2150	56	2022-02-21	cash	2022-02-28	2022-03-28	3500000	paid
2151	56	2022-03-21	cash	2022-03-28	2022-04-28	3500000	paid
2152	56	2022-04-21	cash	2022-04-28	2022-05-28	3500000	paid
2153	56	2022-05-21	cash	2022-05-28	2022-06-28	3500000	paid
2154	56	2022-06-21	cash	2022-06-28	2022-07-28	3500000	paid
2155	56	2022-07-21	cash	2022-07-28	2022-08-28	3500000	paid
2156	56	2022-08-21	cash	2022-08-28	2022-09-28	3500000	paid
2157	56	2022-09-21	cash	2022-09-28	2022-10-28	3500000	paid
2158	56	2022-10-21	cash	2022-10-28	2022-11-28	3500000	paid
2159	56	2022-11-21	cash	2022-11-28	2022-12-28	3500000	paid
2173	57	2021-08-11	cash	2021-08-18	2021-09-18	1400000	paid
2174	57	2021-09-11	cash	2021-09-18	2021-10-18	1400000	paid
2175	57	2021-10-11	cash	2021-10-18	2021-11-18	1400000	paid
2176	57	2021-11-11	cash	2021-11-18	2021-12-18	1400000	paid
2177	57	2021-12-11	cash	2021-12-18	2022-01-18	1400000	paid
2178	57	2022-01-11	cash	2022-01-18	2022-02-18	1400000	paid
2179	57	2022-02-11	cash	2022-02-18	2022-03-18	1400000	paid
2180	57	2022-03-11	cash	2022-03-18	2022-04-18	1400000	paid
2181	57	2022-04-11	cash	2022-04-18	2022-05-18	1400000	paid
2182	57	2022-05-11	cash	2022-05-18	2022-06-18	1400000	paid
2183	57	2022-06-11	cash	2022-06-18	2022-07-18	1400000	paid
2184	57	2022-07-11	cash	2022-07-18	2022-08-18	1400000	paid
2185	57	2022-08-11	cash	2022-08-18	2022-09-18	1400000	paid
2186	57	2022-09-11	cash	2022-09-18	2022-10-18	1400000	paid
2187	57	2022-10-11	cash	2022-10-18	2022-11-18	1400000	paid
2188	57	2022-11-11	cash	2022-11-18	2022-12-18	1400000	paid
2221	58	2020-05-11	cash	2020-05-18	2020-06-18	9600000	paid
2222	58	2020-06-11	cash	2020-06-18	2020-07-18	9600000	paid
2223	58	2020-07-11	cash	2020-07-18	2020-08-18	9600000	paid
2224	58	2020-08-11	cash	2020-08-18	2020-09-18	9600000	paid
2225	58	2020-09-11	cash	2020-09-18	2020-10-18	9600000	paid
2226	58	2020-10-11	cash	2020-10-18	2020-11-18	9600000	paid
2227	58	2020-11-11	cash	2020-11-18	2020-12-18	9600000	paid
2228	58	2020-12-11	cash	2020-12-18	2021-01-18	9600000	paid
2229	58	2021-01-11	cash	2021-01-18	2021-02-18	9600000	paid
2230	58	2021-02-11	cash	2021-02-18	2021-03-18	9600000	paid
2231	58	2021-03-11	cash	2021-03-18	2021-04-18	9600000	paid
2232	58	2021-04-11	cash	2021-04-18	2021-05-18	9600000	paid
2233	58	2021-05-11	cash	2021-05-18	2021-06-18	9600000	paid
2234	58	2021-06-11	cash	2021-06-18	2021-07-18	9600000	paid
2235	58	2021-07-11	cash	2021-07-18	2021-08-18	9600000	paid
2236	58	2021-08-11	cash	2021-08-18	2021-09-18	9600000	paid
2350	61	2022-11-27	cash	2022-12-04	2023-01-04	7900000	paid
2351	61	2022-12-28	cash	2023-01-04	2023-02-04	7900000	paid
2400	62	2022-12-16	cash	2022-12-23	2023-01-23	4800000	paid
2401	62	2023-01-16	cash	2023-01-23	2023-02-23	4800000	paid
2237	58	2021-09-11	cash	2021-09-18	2021-10-18	9600000	paid
2238	58	2021-10-11	cash	2021-10-18	2021-11-18	9600000	paid
2239	58	2021-11-11	cash	2021-11-18	2021-12-18	9600000	paid
2240	58	2021-12-11	cash	2021-12-18	2022-01-18	9600000	paid
2241	58	2022-01-11	cash	2022-01-18	2022-02-18	9600000	paid
2242	58	2022-02-11	cash	2022-02-18	2022-03-18	9600000	paid
2243	58	2022-03-11	cash	2022-03-18	2022-04-18	9600000	paid
2244	58	2022-04-11	cash	2022-04-18	2022-05-18	9600000	paid
2245	58	2022-05-11	cash	2022-05-18	2022-06-18	9600000	paid
2246	58	2022-06-11	cash	2022-06-18	2022-07-18	9600000	paid
2247	58	2022-07-11	cash	2022-07-18	2022-08-18	9600000	paid
2248	58	2022-08-11	cash	2022-08-18	2022-09-18	9600000	paid
2249	58	2022-09-11	cash	2022-09-18	2022-10-18	9600000	paid
2250	58	2022-10-11	cash	2022-10-18	2022-11-18	9600000	paid
2251	58	2022-11-11	cash	2022-11-18	2022-12-18	9600000	paid
2269	59	2018-06-02	cash	2018-06-09	2018-07-09	2000000	paid
2270	59	2018-07-02	cash	2018-07-09	2018-08-09	2000000	paid
2271	59	2018-08-02	cash	2018-08-09	2018-09-09	2000000	paid
2272	59	2018-09-02	cash	2018-09-09	2018-10-09	2000000	paid
2273	59	2018-10-02	cash	2018-10-09	2018-11-09	2000000	paid
2274	59	2018-11-02	cash	2018-11-09	2018-12-09	2000000	paid
2275	59	2018-12-02	cash	2018-12-09	2019-01-09	2000000	paid
2276	59	2019-01-02	cash	2019-01-09	2019-02-09	2000000	paid
2277	59	2019-02-02	cash	2019-02-09	2019-03-09	2000000	paid
2278	59	2019-03-02	cash	2019-03-09	2019-04-09	2000000	paid
2279	59	2019-04-02	cash	2019-04-09	2019-05-09	2000000	paid
2280	59	2019-05-02	cash	2019-05-09	2019-06-09	2000000	paid
2281	59	2019-06-02	cash	2019-06-09	2019-07-09	2000000	paid
2282	59	2019-07-02	cash	2019-07-09	2019-08-09	2000000	paid
2283	59	2019-08-02	cash	2019-08-09	2019-09-09	2000000	paid
2284	59	2019-09-02	cash	2019-09-09	2019-10-09	2000000	paid
2285	59	2019-10-02	cash	2019-10-09	2019-11-09	2000000	paid
2286	59	2019-11-02	cash	2019-11-09	2019-12-09	2000000	paid
2287	59	2019-12-02	cash	2019-12-09	2020-01-09	2000000	paid
2288	59	2020-01-02	cash	2020-01-09	2020-02-09	2000000	paid
2289	59	2020-02-02	cash	2020-02-09	2020-03-09	2000000	paid
2290	59	2020-03-02	cash	2020-03-09	2020-04-09	2000000	paid
2291	59	2020-04-02	cash	2020-04-09	2020-05-09	2000000	paid
2292	59	2020-05-02	cash	2020-05-09	2020-06-09	2000000	paid
2293	59	2020-06-02	cash	2020-06-09	2020-07-09	2000000	paid
2294	59	2020-07-02	cash	2020-07-09	2020-08-09	2000000	paid
2295	59	2020-08-02	cash	2020-08-09	2020-09-09	2000000	paid
2296	59	2020-09-02	cash	2020-09-09	2020-10-09	2000000	paid
2297	59	2020-10-02	cash	2020-10-09	2020-11-09	2000000	paid
2298	59	2020-11-02	cash	2020-11-09	2020-12-09	2000000	paid
2299	59	2020-12-02	cash	2020-12-09	2021-01-09	2000000	paid
2300	59	2021-01-02	cash	2021-01-09	2021-02-09	2000000	paid
2301	59	2021-02-02	cash	2021-02-09	2021-03-09	2000000	paid
2302	59	2021-03-02	cash	2021-03-09	2021-04-09	2000000	paid
2303	59	2021-04-02	cash	2021-04-09	2021-05-09	2000000	paid
2304	59	2021-05-02	cash	2021-05-09	2021-06-09	2000000	paid
2305	60	2020-01-02	cash	2020-01-09	2020-02-09	9500000	paid
2306	60	2020-02-02	cash	2020-02-09	2020-03-09	9500000	paid
2307	60	2020-03-02	cash	2020-03-09	2020-04-09	9500000	paid
2308	60	2020-04-02	cash	2020-04-09	2020-05-09	9500000	paid
2309	60	2020-05-02	cash	2020-05-09	2020-06-09	9500000	paid
2310	60	2020-06-02	cash	2020-06-09	2020-07-09	9500000	paid
2311	60	2020-07-02	cash	2020-07-09	2020-08-09	9500000	paid
2312	60	2020-08-02	cash	2020-08-09	2020-09-09	9500000	paid
2313	60	2020-09-02	cash	2020-09-09	2020-10-09	9500000	paid
2314	60	2020-10-02	cash	2020-10-09	2020-11-09	9500000	paid
2315	60	2020-11-02	cash	2020-11-09	2020-12-09	9500000	paid
2316	60	2020-12-02	cash	2020-12-09	2021-01-09	9500000	paid
2317	61	2020-02-26	cash	2020-03-04	2020-04-04	7900000	paid
2318	61	2020-03-28	cash	2020-04-04	2020-05-04	7900000	paid
2319	61	2020-04-27	cash	2020-05-04	2020-06-04	7900000	paid
2320	61	2020-05-28	cash	2020-06-04	2020-07-04	7900000	paid
2321	61	2020-06-27	cash	2020-07-04	2020-08-04	7900000	paid
2322	61	2020-07-28	cash	2020-08-04	2020-09-04	7900000	paid
2323	61	2020-08-28	cash	2020-09-04	2020-10-04	7900000	paid
2324	61	2020-09-27	cash	2020-10-04	2020-11-04	7900000	paid
2325	61	2020-10-28	cash	2020-11-04	2020-12-04	7900000	paid
2326	61	2020-11-27	cash	2020-12-04	2021-01-04	7900000	paid
2327	61	2020-12-28	cash	2021-01-04	2021-02-04	7900000	paid
2328	61	2021-01-28	cash	2021-02-04	2021-03-04	7900000	paid
2329	61	2021-02-25	cash	2021-03-04	2021-04-04	7900000	paid
2330	61	2021-03-28	cash	2021-04-04	2021-05-04	7900000	paid
2331	61	2021-04-27	cash	2021-05-04	2021-06-04	7900000	paid
2332	61	2021-05-28	cash	2021-06-04	2021-07-04	7900000	paid
2333	61	2021-06-27	cash	2021-07-04	2021-08-04	7900000	paid
2334	61	2021-07-28	cash	2021-08-04	2021-09-04	7900000	paid
2335	61	2021-08-28	cash	2021-09-04	2021-10-04	7900000	paid
2336	61	2021-09-27	cash	2021-10-04	2021-11-04	7900000	paid
2337	61	2021-10-28	cash	2021-11-04	2021-12-04	7900000	paid
2338	61	2021-11-27	cash	2021-12-04	2022-01-04	7900000	paid
2339	61	2021-12-28	cash	2022-01-04	2022-02-04	7900000	paid
2340	61	2022-01-28	cash	2022-02-04	2022-03-04	7900000	paid
2341	61	2022-02-25	cash	2022-03-04	2022-04-04	7900000	paid
2342	61	2022-03-28	cash	2022-04-04	2022-05-04	7900000	paid
2343	61	2022-04-27	cash	2022-05-04	2022-06-04	7900000	paid
2344	61	2022-05-28	cash	2022-06-04	2022-07-04	7900000	paid
2345	61	2022-06-27	cash	2022-07-04	2022-08-04	7900000	paid
2567	70	2022-12-02	cash	2022-12-09	2023-01-09	2600000	paid
2568	70	2023-01-02	cash	2023-01-09	2023-02-09	2600000	paid
2346	61	2022-07-28	cash	2022-08-04	2022-09-04	7900000	paid
2347	61	2022-08-28	cash	2022-09-04	2022-10-04	7900000	paid
2348	61	2022-09-27	cash	2022-10-04	2022-11-04	7900000	paid
2349	61	2022-10-28	cash	2022-11-04	2022-12-04	7900000	paid
2365	62	2020-01-16	cash	2020-01-23	2020-02-23	4800000	paid
2366	62	2020-02-16	cash	2020-02-23	2020-03-23	4800000	paid
2367	62	2020-03-16	cash	2020-03-23	2020-04-23	4800000	paid
2368	62	2020-04-16	cash	2020-04-23	2020-05-23	4800000	paid
2369	62	2020-05-16	cash	2020-05-23	2020-06-23	4800000	paid
2370	62	2020-06-16	cash	2020-06-23	2020-07-23	4800000	paid
2371	62	2020-07-16	cash	2020-07-23	2020-08-23	4800000	paid
2372	62	2020-08-16	cash	2020-08-23	2020-09-23	4800000	paid
2373	62	2020-09-16	cash	2020-09-23	2020-10-23	4800000	paid
2374	62	2020-10-16	cash	2020-10-23	2020-11-23	4800000	paid
2375	62	2020-11-16	cash	2020-11-23	2020-12-23	4800000	paid
2376	62	2020-12-16	cash	2020-12-23	2021-01-23	4800000	paid
2377	62	2021-01-16	cash	2021-01-23	2021-02-23	4800000	paid
2378	62	2021-02-16	cash	2021-02-23	2021-03-23	4800000	paid
2379	62	2021-03-16	cash	2021-03-23	2021-04-23	4800000	paid
2380	62	2021-04-16	cash	2021-04-23	2021-05-23	4800000	paid
2381	62	2021-05-16	cash	2021-05-23	2021-06-23	4800000	paid
2382	62	2021-06-16	cash	2021-06-23	2021-07-23	4800000	paid
2383	62	2021-07-16	cash	2021-07-23	2021-08-23	4800000	paid
2384	62	2021-08-16	cash	2021-08-23	2021-09-23	4800000	paid
2385	62	2021-09-16	cash	2021-09-23	2021-10-23	4800000	paid
2386	62	2021-10-16	cash	2021-10-23	2021-11-23	4800000	paid
2387	62	2021-11-16	cash	2021-11-23	2021-12-23	4800000	paid
2388	62	2021-12-16	cash	2021-12-23	2022-01-23	4800000	paid
2389	62	2022-01-16	cash	2022-01-23	2022-02-23	4800000	paid
2390	62	2022-02-16	cash	2022-02-23	2022-03-23	4800000	paid
2391	62	2022-03-16	cash	2022-03-23	2022-04-23	4800000	paid
2392	62	2022-04-16	cash	2022-04-23	2022-05-23	4800000	paid
2393	62	2022-05-16	cash	2022-05-23	2022-06-23	4800000	paid
2394	62	2022-06-16	cash	2022-06-23	2022-07-23	4800000	paid
2395	62	2022-07-16	cash	2022-07-23	2022-08-23	4800000	paid
2396	62	2022-08-16	cash	2022-08-23	2022-09-23	4800000	paid
2397	62	2022-09-16	cash	2022-09-23	2022-10-23	4800000	paid
2398	62	2022-10-16	cash	2022-10-23	2022-11-23	4800000	paid
2399	62	2022-11-16	cash	2022-11-23	2022-12-23	4800000	paid
2425	63	2018-08-20	cash	2018-08-27	2018-09-27	6500000	paid
2426	63	2018-09-20	cash	2018-09-27	2018-10-27	6500000	paid
2427	63	2018-10-20	cash	2018-10-27	2018-11-27	6500000	paid
2428	63	2018-11-20	cash	2018-11-27	2018-12-27	6500000	paid
2429	63	2018-12-20	cash	2018-12-27	2019-01-27	6500000	paid
2430	63	2019-01-20	cash	2019-01-27	2019-02-27	6500000	paid
2431	63	2019-02-20	cash	2019-02-27	2019-03-27	6500000	paid
2432	63	2019-03-20	cash	2019-03-27	2019-04-27	6500000	paid
2433	63	2019-04-20	cash	2019-04-27	2019-05-27	6500000	paid
2434	63	2019-05-20	cash	2019-05-27	2019-06-27	6500000	paid
2435	63	2019-06-20	cash	2019-06-27	2019-07-27	6500000	paid
2436	63	2019-07-20	cash	2019-07-27	2019-08-27	6500000	paid
2437	63	2019-08-20	cash	2019-08-27	2019-09-27	6500000	paid
2438	63	2019-09-20	cash	2019-09-27	2019-10-27	6500000	paid
2439	63	2019-10-20	cash	2019-10-27	2019-11-27	6500000	paid
2440	63	2019-11-20	cash	2019-11-27	2019-12-27	6500000	paid
2441	63	2019-12-20	cash	2019-12-27	2020-01-27	6500000	paid
2442	63	2020-01-20	cash	2020-01-27	2020-02-27	6500000	paid
2443	63	2020-02-20	cash	2020-02-27	2020-03-27	6500000	paid
2444	63	2020-03-20	cash	2020-03-27	2020-04-27	6500000	paid
2445	63	2020-04-20	cash	2020-04-27	2020-05-27	6500000	paid
2446	63	2020-05-20	cash	2020-05-27	2020-06-27	6500000	paid
2447	63	2020-06-20	cash	2020-06-27	2020-07-27	6500000	paid
2448	63	2020-07-20	cash	2020-07-27	2020-08-27	6500000	paid
2449	63	2020-08-20	cash	2020-08-27	2020-09-27	6500000	paid
2450	63	2020-09-20	cash	2020-09-27	2020-10-27	6500000	paid
2451	63	2020-10-20	cash	2020-10-27	2020-11-27	6500000	paid
2452	63	2020-11-20	cash	2020-11-27	2020-12-27	6500000	paid
2453	63	2020-12-20	cash	2020-12-27	2021-01-27	6500000	paid
2454	63	2021-01-20	cash	2021-01-27	2021-02-27	6500000	paid
2455	63	2021-02-20	cash	2021-02-27	2021-03-27	6500000	paid
2456	63	2021-03-20	cash	2021-03-27	2021-04-27	6500000	paid
2457	63	2021-04-20	cash	2021-04-27	2021-05-27	6500000	paid
2458	63	2021-05-20	cash	2021-05-27	2021-06-27	6500000	paid
2459	63	2021-06-20	cash	2021-06-27	2021-07-27	6500000	paid
2460	63	2021-07-20	cash	2021-07-27	2021-08-27	6500000	paid
2461	63	2021-08-20	cash	2021-08-27	2021-09-27	6500000	paid
2462	63	2021-09-20	cash	2021-09-27	2021-10-27	6500000	paid
2463	63	2021-10-20	cash	2021-10-27	2021-11-27	6500000	paid
2464	63	2021-11-20	cash	2021-11-27	2021-12-27	6500000	paid
2465	63	2021-12-20	cash	2021-12-27	2022-01-27	6500000	paid
2466	63	2022-01-20	cash	2022-01-27	2022-02-27	6500000	paid
2467	63	2022-02-20	cash	2022-02-27	2022-03-27	6500000	paid
2468	63	2022-03-20	cash	2022-03-27	2022-04-27	6500000	paid
2469	63	2022-04-20	cash	2022-04-27	2022-05-27	6500000	paid
2470	63	2022-05-20	cash	2022-05-27	2022-06-27	6500000	paid
2471	63	2022-06-20	cash	2022-06-27	2022-07-27	6500000	paid
2472	63	2022-07-20	cash	2022-07-27	2022-08-27	6500000	paid
2473	64	2018-11-12	cash	2018-11-19	2018-12-19	5400000	paid
2474	64	2018-12-12	cash	2018-12-19	2019-01-19	5400000	paid
2475	64	2019-01-12	cash	2019-01-19	2019-02-19	5400000	paid
2476	64	2019-02-12	cash	2019-02-19	2019-03-19	5400000	paid
2477	64	2019-03-12	cash	2019-03-19	2019-04-19	5400000	paid
2478	64	2019-04-12	cash	2019-04-19	2019-05-19	5400000	paid
2479	64	2019-05-12	cash	2019-05-19	2019-06-19	5400000	paid
2480	64	2019-06-12	cash	2019-06-19	2019-07-19	5400000	paid
2481	64	2019-07-12	cash	2019-07-19	2019-08-19	5400000	paid
2482	64	2019-08-12	cash	2019-08-19	2019-09-19	5400000	paid
2483	64	2019-09-12	cash	2019-09-19	2019-10-19	5400000	paid
2484	64	2019-10-12	cash	2019-10-19	2019-11-19	5400000	paid
2497	66	2020-03-04	cash	2020-03-11	2020-04-11	8500000	paid
2498	66	2020-04-04	cash	2020-04-11	2020-05-11	8500000	paid
2499	66	2020-05-04	cash	2020-05-11	2020-06-11	8500000	paid
2500	66	2020-06-04	cash	2020-06-11	2020-07-11	8500000	paid
2501	66	2020-07-04	cash	2020-07-11	2020-08-11	8500000	paid
2635	71	2022-11-30	cash	2022-12-07	2023-01-07	100000	paid
2636	71	2022-12-31	cash	2023-01-07	2023-02-07	100000	paid
2665	72	2022-12-21	cash	2022-12-28	2023-01-28	8900000	paid
2666	72	2023-01-21	cash	2023-01-28	2023-02-28	8900000	paid
2502	66	2020-08-04	cash	2020-08-11	2020-09-11	8500000	paid
2503	66	2020-09-04	cash	2020-09-11	2020-10-11	8500000	paid
2504	66	2020-10-04	cash	2020-10-11	2020-11-11	8500000	paid
2505	66	2020-11-04	cash	2020-11-11	2020-12-11	8500000	paid
2506	66	2020-12-04	cash	2020-12-11	2021-01-11	8500000	paid
2507	66	2021-01-04	cash	2021-01-11	2021-02-11	8500000	paid
2508	66	2021-02-04	cash	2021-02-11	2021-03-11	8500000	paid
2509	66	2021-03-04	cash	2021-03-11	2021-04-11	8500000	paid
2510	66	2021-04-04	cash	2021-04-11	2021-05-11	8500000	paid
2511	66	2021-05-04	cash	2021-05-11	2021-06-11	8500000	paid
2512	66	2021-06-04	cash	2021-06-11	2021-07-11	8500000	paid
2513	66	2021-07-04	cash	2021-07-11	2021-08-11	8500000	paid
2514	66	2021-08-04	cash	2021-08-11	2021-09-11	8500000	paid
2515	66	2021-09-04	cash	2021-09-11	2021-10-11	8500000	paid
2516	66	2021-10-04	cash	2021-10-11	2021-11-11	8500000	paid
2517	66	2021-11-04	cash	2021-11-11	2021-12-11	8500000	paid
2518	66	2021-12-04	cash	2021-12-11	2022-01-11	8500000	paid
2519	66	2022-01-04	cash	2022-01-11	2022-02-11	8500000	paid
2520	66	2022-02-04	cash	2022-02-11	2022-03-11	8500000	paid
2521	67	2018-04-10	cash	2018-04-17	2018-05-17	2800000	paid
2522	67	2018-05-10	cash	2018-05-17	2018-06-17	2800000	paid
2523	67	2018-06-10	cash	2018-06-17	2018-07-17	2800000	paid
2524	67	2018-07-10	cash	2018-07-17	2018-08-17	2800000	paid
2525	67	2018-08-10	cash	2018-08-17	2018-09-17	2800000	paid
2526	67	2018-09-10	cash	2018-09-17	2018-10-17	2800000	paid
2527	67	2018-10-10	cash	2018-10-17	2018-11-17	2800000	paid
2528	67	2018-11-10	cash	2018-11-17	2018-12-17	2800000	paid
2529	67	2018-12-10	cash	2018-12-17	2019-01-17	2800000	paid
2530	67	2019-01-10	cash	2019-01-17	2019-02-17	2800000	paid
2531	67	2019-02-10	cash	2019-02-17	2019-03-17	2800000	paid
2532	67	2019-03-10	cash	2019-03-17	2019-04-17	2800000	paid
2533	68	2018-12-12	cash	2018-12-19	2019-01-19	3500000	paid
2534	68	2019-01-12	cash	2019-01-19	2019-02-19	3500000	paid
2535	68	2019-02-12	cash	2019-02-19	2019-03-19	3500000	paid
2536	68	2019-03-12	cash	2019-03-19	2019-04-19	3500000	paid
2537	68	2019-04-12	cash	2019-04-19	2019-05-19	3500000	paid
2538	68	2019-05-12	cash	2019-05-19	2019-06-19	3500000	paid
2539	68	2019-06-12	cash	2019-06-19	2019-07-19	3500000	paid
2540	68	2019-07-12	cash	2019-07-19	2019-08-19	3500000	paid
2541	68	2019-08-12	cash	2019-08-19	2019-09-19	3500000	paid
2542	68	2019-09-12	cash	2019-09-19	2019-10-19	3500000	paid
2543	68	2019-10-12	cash	2019-10-19	2019-11-19	3500000	paid
2544	68	2019-11-12	cash	2019-11-19	2019-12-19	3500000	paid
2545	69	2020-12-24	cash	2020-12-31	2021-01-31	200000	paid
2546	69	2021-01-24	cash	2021-01-31	2021-02-28	200000	paid
2547	69	2021-02-21	cash	2021-02-28	2021-03-28	200000	paid
2548	69	2021-03-21	cash	2021-03-28	2021-04-28	200000	paid
2549	69	2021-04-21	cash	2021-04-28	2021-05-28	200000	paid
2550	69	2021-05-21	cash	2021-05-28	2021-06-28	200000	paid
2551	69	2021-06-21	cash	2021-06-28	2021-07-28	200000	paid
2552	69	2021-07-21	cash	2021-07-28	2021-08-28	200000	paid
2553	69	2021-08-21	cash	2021-08-28	2021-09-28	200000	paid
2554	69	2021-09-21	cash	2021-09-28	2021-10-28	200000	paid
2555	69	2021-10-21	cash	2021-10-28	2021-11-28	200000	paid
2556	69	2021-11-21	cash	2021-11-28	2021-12-28	200000	paid
2557	70	2022-02-02	cash	2022-02-09	2022-03-09	2600000	paid
2558	70	2022-03-02	cash	2022-03-09	2022-04-09	2600000	paid
2559	70	2022-04-02	cash	2022-04-09	2022-05-09	2600000	paid
2753	75	2022-12-04	cash	2022-12-11	2023-01-11	9100000	paid
2754	75	2023-01-04	cash	2023-01-11	2023-02-11	9100000	paid
2560	70	2022-05-02	cash	2022-05-09	2022-06-09	2600000	paid
2561	70	2022-06-02	cash	2022-06-09	2022-07-09	2600000	paid
2562	70	2022-07-02	cash	2022-07-09	2022-08-09	2600000	paid
2563	70	2022-08-02	cash	2022-08-09	2022-09-09	2600000	paid
2564	70	2022-09-02	cash	2022-09-09	2022-10-09	2600000	paid
2565	70	2022-10-02	cash	2022-10-09	2022-11-09	2600000	paid
2566	70	2022-11-02	cash	2022-11-09	2022-12-09	2600000	paid
2617	71	2021-05-31	cash	2021-06-07	2021-07-07	100000	paid
2618	71	2021-06-30	cash	2021-07-07	2021-08-07	100000	paid
2619	71	2021-07-31	cash	2021-08-07	2021-09-07	100000	paid
2620	71	2021-08-31	cash	2021-09-07	2021-10-07	100000	paid
2621	71	2021-09-30	cash	2021-10-07	2021-11-07	100000	paid
2622	71	2021-10-31	cash	2021-11-07	2021-12-07	100000	paid
2623	71	2021-11-30	cash	2021-12-07	2022-01-07	100000	paid
2624	71	2021-12-31	cash	2022-01-07	2022-02-07	100000	paid
2625	71	2022-01-31	cash	2022-02-07	2022-03-07	100000	paid
2626	71	2022-02-28	cash	2022-03-07	2022-04-07	100000	paid
2627	71	2022-03-31	cash	2022-04-07	2022-05-07	100000	paid
2628	71	2022-04-30	cash	2022-05-07	2022-06-07	100000	paid
2629	71	2022-05-31	cash	2022-06-07	2022-07-07	100000	paid
2630	71	2022-06-30	cash	2022-07-07	2022-08-07	100000	paid
2631	71	2022-07-31	cash	2022-08-07	2022-09-07	100000	paid
2632	71	2022-08-31	cash	2022-09-07	2022-10-07	100000	paid
2633	71	2022-09-30	cash	2022-10-07	2022-11-07	100000	paid
2634	71	2022-10-31	cash	2022-11-07	2022-12-07	100000	paid
2641	72	2020-12-21	cash	2020-12-28	2021-01-28	8900000	paid
2642	72	2021-01-21	cash	2021-01-28	2021-02-28	8900000	paid
2643	72	2021-02-21	cash	2021-02-28	2021-03-28	8900000	paid
2644	72	2021-03-21	cash	2021-03-28	2021-04-28	8900000	paid
2645	72	2021-04-21	cash	2021-04-28	2021-05-28	8900000	paid
2646	72	2021-05-21	cash	2021-05-28	2021-06-28	8900000	paid
2647	72	2021-06-21	cash	2021-06-28	2021-07-28	8900000	paid
2648	72	2021-07-21	cash	2021-07-28	2021-08-28	8900000	paid
2649	72	2021-08-21	cash	2021-08-28	2021-09-28	8900000	paid
2650	72	2021-09-21	cash	2021-09-28	2021-10-28	8900000	paid
2651	72	2021-10-21	cash	2021-10-28	2021-11-28	8900000	paid
2652	72	2021-11-21	cash	2021-11-28	2021-12-28	8900000	paid
2653	72	2021-12-21	cash	2021-12-28	2022-01-28	8900000	paid
2654	72	2022-01-21	cash	2022-01-28	2022-02-28	8900000	paid
2655	72	2022-02-21	cash	2022-02-28	2022-03-28	8900000	paid
2656	72	2022-03-21	cash	2022-03-28	2022-04-28	8900000	paid
2657	72	2022-04-21	cash	2022-04-28	2022-05-28	8900000	paid
2658	72	2022-05-21	cash	2022-05-28	2022-06-28	8900000	paid
2659	72	2022-06-21	cash	2022-06-28	2022-07-28	8900000	paid
2660	72	2022-07-21	cash	2022-07-28	2022-08-28	8900000	paid
2661	72	2022-08-21	cash	2022-08-28	2022-09-28	8900000	paid
2662	72	2022-09-21	cash	2022-09-28	2022-10-28	8900000	paid
2663	72	2022-10-21	cash	2022-10-28	2022-11-28	8900000	paid
2664	72	2022-11-21	cash	2022-11-28	2022-12-28	8900000	paid
2701	73	2018-11-21	cash	2018-11-28	2018-12-28	9400000	paid
2702	73	2018-12-21	cash	2018-12-28	2019-01-28	9400000	paid
2703	73	2019-01-21	cash	2019-01-28	2019-02-28	9400000	paid
2704	73	2019-02-21	cash	2019-02-28	2019-03-28	9400000	paid
2705	73	2019-03-21	cash	2019-03-28	2019-04-28	9400000	paid
2706	73	2019-04-21	cash	2019-04-28	2019-05-28	9400000	paid
2707	73	2019-05-21	cash	2019-05-28	2019-06-28	9400000	paid
2708	73	2019-06-21	cash	2019-06-28	2019-07-28	9400000	paid
2709	73	2019-07-21	cash	2019-07-28	2019-08-28	9400000	paid
2710	73	2019-08-21	cash	2019-08-28	2019-09-28	9400000	paid
2711	73	2019-09-21	cash	2019-09-28	2019-10-28	9400000	paid
2712	73	2019-10-21	cash	2019-10-28	2019-11-28	9400000	paid
2713	74	2018-05-23	cash	2018-05-30	2018-06-30	1900000	paid
2714	74	2018-06-23	cash	2018-06-30	2018-07-30	1900000	paid
2715	74	2018-07-23	cash	2018-07-30	2018-08-30	1900000	paid
2716	74	2018-08-23	cash	2018-08-30	2018-09-30	1900000	paid
2717	74	2018-09-23	cash	2018-09-30	2018-10-30	1900000	paid
2718	74	2018-10-23	cash	2018-10-30	2018-11-30	1900000	paid
2719	74	2018-11-23	cash	2018-11-30	2018-12-30	1900000	paid
2720	74	2018-12-23	cash	2018-12-30	2019-01-30	1900000	paid
2721	74	2019-01-23	cash	2019-01-30	2019-02-28	1900000	paid
2722	74	2019-02-21	cash	2019-02-28	2019-03-28	1900000	paid
2723	74	2019-03-21	cash	2019-03-28	2019-04-28	1900000	paid
2724	74	2019-04-21	cash	2019-04-28	2019-05-28	1900000	paid
2725	74	2019-05-21	cash	2019-05-28	2019-06-28	1900000	paid
2726	74	2019-06-21	cash	2019-06-28	2019-07-28	1900000	paid
2727	74	2019-07-21	cash	2019-07-28	2019-08-28	1900000	paid
2728	74	2019-08-21	cash	2019-08-28	2019-09-28	1900000	paid
2729	74	2019-09-21	cash	2019-09-28	2019-10-28	1900000	paid
2730	74	2019-10-21	cash	2019-10-28	2019-11-28	1900000	paid
2731	74	2019-11-21	cash	2019-11-28	2019-12-28	1900000	paid
2732	74	2019-12-21	cash	2019-12-28	2020-01-28	1900000	paid
2733	74	2020-01-21	cash	2020-01-28	2020-02-28	1900000	paid
2734	74	2020-02-21	cash	2020-02-28	2020-03-28	1900000	paid
2735	74	2020-03-21	cash	2020-03-28	2020-04-28	1900000	paid
2736	74	2020-04-21	cash	2020-04-28	2020-05-28	1900000	paid
2737	75	2021-08-04	cash	2021-08-11	2021-09-11	9100000	paid
2738	75	2021-09-04	cash	2021-09-11	2021-10-11	9100000	paid
2739	75	2021-10-04	cash	2021-10-11	2021-11-11	9100000	paid
2740	75	2021-11-04	cash	2021-11-11	2021-12-11	9100000	paid
2741	75	2021-12-04	cash	2021-12-11	2022-01-11	9100000	paid
2874	78	2022-12-13	cash	2022-12-20	2023-01-20	8200000	paid
2875	78	2023-01-13	cash	2023-01-20	2023-02-20	8200000	paid
2889	79	2022-12-03	cash	2022-12-10	2023-01-10	6900000	paid
2890	79	2023-01-03	cash	2023-01-10	2023-02-10	6900000	paid
2742	75	2022-01-04	cash	2022-01-11	2022-02-11	9100000	paid
2743	75	2022-02-04	cash	2022-02-11	2022-03-11	9100000	paid
2744	75	2022-03-04	cash	2022-03-11	2022-04-11	9100000	paid
2745	75	2022-04-04	cash	2022-04-11	2022-05-11	9100000	paid
2746	75	2022-05-04	cash	2022-05-11	2022-06-11	9100000	paid
2747	75	2022-06-04	cash	2022-06-11	2022-07-11	9100000	paid
2748	75	2022-07-04	cash	2022-07-11	2022-08-11	9100000	paid
2749	75	2022-08-04	cash	2022-08-11	2022-09-11	9100000	paid
2750	75	2022-09-04	cash	2022-09-11	2022-10-11	9100000	paid
2751	75	2022-10-04	cash	2022-10-11	2022-11-11	9100000	paid
2752	75	2022-11-04	cash	2022-11-11	2022-12-11	9100000	paid
2797	76	2019-12-02	cash	2019-12-09	2020-01-09	6300000	paid
2798	76	2020-01-02	cash	2020-01-09	2020-02-09	6300000	paid
2799	76	2020-02-02	cash	2020-02-09	2020-03-09	6300000	paid
2800	76	2020-03-02	cash	2020-03-09	2020-04-09	6300000	paid
2801	76	2020-04-02	cash	2020-04-09	2020-05-09	6300000	paid
2802	76	2020-05-02	cash	2020-05-09	2020-06-09	6300000	paid
2803	76	2020-06-02	cash	2020-06-09	2020-07-09	6300000	paid
2804	76	2020-07-02	cash	2020-07-09	2020-08-09	6300000	paid
2805	76	2020-08-02	cash	2020-08-09	2020-09-09	6300000	paid
2806	76	2020-09-02	cash	2020-09-09	2020-10-09	6300000	paid
2807	76	2020-10-02	cash	2020-10-09	2020-11-09	6300000	paid
2808	76	2020-11-02	cash	2020-11-09	2020-12-09	6300000	paid
2809	77	2020-09-23	cash	2020-09-30	2020-10-30	1700000	paid
2810	77	2020-10-23	cash	2020-10-30	2020-11-30	1700000	paid
2811	77	2020-11-23	cash	2020-11-30	2020-12-30	1700000	paid
2812	77	2020-12-23	cash	2020-12-30	2021-01-30	1700000	paid
2813	77	2021-01-23	cash	2021-01-30	2021-02-28	1700000	paid
2814	77	2021-02-21	cash	2021-02-28	2021-03-28	1700000	paid
2815	77	2021-03-21	cash	2021-03-28	2021-04-28	1700000	paid
2816	77	2021-04-21	cash	2021-04-28	2021-05-28	1700000	paid
2817	77	2021-05-21	cash	2021-05-28	2021-06-28	1700000	paid
2818	77	2021-06-21	cash	2021-06-28	2021-07-28	1700000	paid
2819	77	2021-07-21	cash	2021-07-28	2021-08-28	1700000	paid
2820	77	2021-08-21	cash	2021-08-28	2021-09-28	1700000	paid
2821	78	2018-07-13	cash	2018-07-20	2018-08-20	8200000	paid
2822	78	2018-08-13	cash	2018-08-20	2018-09-20	8200000	paid
2823	78	2018-09-13	cash	2018-09-20	2018-10-20	8200000	paid
2824	78	2018-10-13	cash	2018-10-20	2018-11-20	8200000	paid
2825	78	2018-11-13	cash	2018-11-20	2018-12-20	8200000	paid
2826	78	2018-12-13	cash	2018-12-20	2019-01-20	8200000	paid
2827	78	2019-01-13	cash	2019-01-20	2019-02-20	8200000	paid
2828	78	2019-02-13	cash	2019-02-20	2019-03-20	8200000	paid
2829	78	2019-03-13	cash	2019-03-20	2019-04-20	8200000	paid
2830	78	2019-04-13	cash	2019-04-20	2019-05-20	8200000	paid
2831	78	2019-05-13	cash	2019-05-20	2019-06-20	8200000	paid
2832	78	2019-06-13	cash	2019-06-20	2019-07-20	8200000	paid
2833	78	2019-07-13	cash	2019-07-20	2019-08-20	8200000	paid
2834	78	2019-08-13	cash	2019-08-20	2019-09-20	8200000	paid
2835	78	2019-09-13	cash	2019-09-20	2019-10-20	8200000	paid
2836	78	2019-10-13	cash	2019-10-20	2019-11-20	8200000	paid
2837	78	2019-11-13	cash	2019-11-20	2019-12-20	8200000	paid
2838	78	2019-12-13	cash	2019-12-20	2020-01-20	8200000	paid
2839	78	2020-01-13	cash	2020-01-20	2020-02-20	8200000	paid
2840	78	2020-02-13	cash	2020-02-20	2020-03-20	8200000	paid
2841	78	2020-03-13	cash	2020-03-20	2020-04-20	8200000	paid
2842	78	2020-04-13	cash	2020-04-20	2020-05-20	8200000	paid
2843	78	2020-05-13	cash	2020-05-20	2020-06-20	8200000	paid
2844	78	2020-06-13	cash	2020-06-20	2020-07-20	8200000	paid
2845	78	2020-07-13	cash	2020-07-20	2020-08-20	8200000	paid
2846	78	2020-08-13	cash	2020-08-20	2020-09-20	8200000	paid
2847	78	2020-09-13	cash	2020-09-20	2020-10-20	8200000	paid
2848	78	2020-10-13	cash	2020-10-20	2020-11-20	8200000	paid
2849	78	2020-11-13	cash	2020-11-20	2020-12-20	8200000	paid
2850	78	2020-12-13	cash	2020-12-20	2021-01-20	8200000	paid
2851	78	2021-01-13	cash	2021-01-20	2021-02-20	8200000	paid
2852	78	2021-02-13	cash	2021-02-20	2021-03-20	8200000	paid
2853	78	2021-03-13	cash	2021-03-20	2021-04-20	8200000	paid
2854	78	2021-04-13	cash	2021-04-20	2021-05-20	8200000	paid
2855	78	2021-05-13	cash	2021-05-20	2021-06-20	8200000	paid
2856	78	2021-06-13	cash	2021-06-20	2021-07-20	8200000	paid
2857	78	2021-07-13	cash	2021-07-20	2021-08-20	8200000	paid
2858	78	2021-08-13	cash	2021-08-20	2021-09-20	8200000	paid
3002	82	2022-12-19	cash	2022-12-26	2023-01-26	7900000	paid
3003	82	2023-01-19	cash	2023-01-26	2023-02-26	7900000	paid
3028	84	2022-11-30	cash	2022-12-07	2023-01-07	2400000	paid
3029	84	2022-12-31	cash	2023-01-07	2023-02-07	2400000	paid
3091	85	2022-12-21	cash	2022-12-28	2023-01-28	2900000	paid
3092	85	2023-01-21	cash	2023-01-28	2023-02-28	2900000	paid
2859	78	2021-09-13	cash	2021-09-20	2021-10-20	8200000	paid
2860	78	2021-10-13	cash	2021-10-20	2021-11-20	8200000	paid
2861	78	2021-11-13	cash	2021-11-20	2021-12-20	8200000	paid
2862	78	2021-12-13	cash	2021-12-20	2022-01-20	8200000	paid
2863	78	2022-01-13	cash	2022-01-20	2022-02-20	8200000	paid
2864	78	2022-02-13	cash	2022-02-20	2022-03-20	8200000	paid
2865	78	2022-03-13	cash	2022-03-20	2022-04-20	8200000	paid
2866	78	2022-04-13	cash	2022-04-20	2022-05-20	8200000	paid
2867	78	2022-05-13	cash	2022-05-20	2022-06-20	8200000	paid
2868	78	2022-06-13	cash	2022-06-20	2022-07-20	8200000	paid
2869	78	2022-07-13	cash	2022-07-20	2022-08-20	8200000	paid
2870	78	2022-08-13	cash	2022-08-20	2022-09-20	8200000	paid
2871	78	2022-09-13	cash	2022-09-20	2022-10-20	8200000	paid
2872	78	2022-10-13	cash	2022-10-20	2022-11-20	8200000	paid
2873	78	2022-11-13	cash	2022-11-20	2022-12-20	8200000	paid
2881	79	2022-04-03	cash	2022-04-10	2022-05-10	6900000	paid
2882	79	2022-05-03	cash	2022-05-10	2022-06-10	6900000	paid
2883	79	2022-06-03	cash	2022-06-10	2022-07-10	6900000	paid
2884	79	2022-07-03	cash	2022-07-10	2022-08-10	6900000	paid
2885	79	2022-08-03	cash	2022-08-10	2022-09-10	6900000	paid
2886	79	2022-09-03	cash	2022-09-10	2022-10-10	6900000	paid
2887	79	2022-10-03	cash	2022-10-10	2022-11-10	6900000	paid
2888	79	2022-11-03	cash	2022-11-10	2022-12-10	6900000	paid
2941	80	2018-10-12	cash	2018-10-19	2018-11-19	9300000	paid
2942	80	2018-11-12	cash	2018-11-19	2018-12-19	9300000	paid
2943	80	2018-12-12	cash	2018-12-19	2019-01-19	9300000	paid
2944	80	2019-01-12	cash	2019-01-19	2019-02-19	9300000	paid
2945	80	2019-02-12	cash	2019-02-19	2019-03-19	9300000	paid
2946	80	2019-03-12	cash	2019-03-19	2019-04-19	9300000	paid
2947	80	2019-04-12	cash	2019-04-19	2019-05-19	9300000	paid
2948	80	2019-05-12	cash	2019-05-19	2019-06-19	9300000	paid
2949	80	2019-06-12	cash	2019-06-19	2019-07-19	9300000	paid
2950	80	2019-07-12	cash	2019-07-19	2019-08-19	9300000	paid
2951	80	2019-08-12	cash	2019-08-19	2019-09-19	9300000	paid
2952	80	2019-09-12	cash	2019-09-19	2019-10-19	9300000	paid
2953	80	2019-10-12	cash	2019-10-19	2019-11-19	9300000	paid
3186	86	2022-11-30	cash	2022-12-07	2023-01-07	7000000	paid
3187	86	2022-12-31	cash	2023-01-07	2023-02-07	7000000	paid
3200	87	2022-11-30	cash	2022-12-07	2023-01-07	400000	paid
3201	87	2022-12-31	cash	2023-01-07	2023-02-07	400000	paid
2954	80	2019-11-12	cash	2019-11-19	2019-12-19	9300000	paid
2955	80	2019-12-12	cash	2019-12-19	2020-01-19	9300000	paid
2956	80	2020-01-12	cash	2020-01-19	2020-02-19	9300000	paid
2957	80	2020-02-12	cash	2020-02-19	2020-03-19	9300000	paid
2958	80	2020-03-12	cash	2020-03-19	2020-04-19	9300000	paid
2959	80	2020-04-12	cash	2020-04-19	2020-05-19	9300000	paid
2960	80	2020-05-12	cash	2020-05-19	2020-06-19	9300000	paid
2961	80	2020-06-12	cash	2020-06-19	2020-07-19	9300000	paid
2962	80	2020-07-12	cash	2020-07-19	2020-08-19	9300000	paid
2963	80	2020-08-12	cash	2020-08-19	2020-09-19	9300000	paid
2964	80	2020-09-12	cash	2020-09-19	2020-10-19	9300000	paid
2965	81	2019-04-03	cash	2019-04-10	2019-05-10	4500000	paid
2966	81	2019-05-03	cash	2019-05-10	2019-06-10	4500000	paid
2967	81	2019-06-03	cash	2019-06-10	2019-07-10	4500000	paid
2968	81	2019-07-03	cash	2019-07-10	2019-08-10	4500000	paid
2969	81	2019-08-03	cash	2019-08-10	2019-09-10	4500000	paid
2970	81	2019-09-03	cash	2019-09-10	2019-10-10	4500000	paid
2971	81	2019-10-03	cash	2019-10-10	2019-11-10	4500000	paid
2972	81	2019-11-03	cash	2019-11-10	2019-12-10	4500000	paid
2973	81	2019-12-03	cash	2019-12-10	2020-01-10	4500000	paid
2974	81	2020-01-03	cash	2020-01-10	2020-02-10	4500000	paid
2975	81	2020-02-03	cash	2020-02-10	2020-03-10	4500000	paid
2976	81	2020-03-03	cash	2020-03-10	2020-04-10	4500000	paid
2977	81	2020-04-03	cash	2020-04-10	2020-05-10	4500000	paid
2978	81	2020-05-03	cash	2020-05-10	2020-06-10	4500000	paid
2979	81	2020-06-03	cash	2020-06-10	2020-07-10	4500000	paid
2980	81	2020-07-03	cash	2020-07-10	2020-08-10	4500000	paid
2981	81	2020-08-03	cash	2020-08-10	2020-09-10	4500000	paid
2982	81	2020-09-03	cash	2020-09-10	2020-10-10	4500000	paid
2983	81	2020-10-03	cash	2020-10-10	2020-11-10	4500000	paid
2984	81	2020-11-03	cash	2020-11-10	2020-12-10	4500000	paid
2985	81	2020-12-03	cash	2020-12-10	2021-01-10	4500000	paid
2986	81	2021-01-03	cash	2021-01-10	2021-02-10	4500000	paid
2987	81	2021-02-03	cash	2021-02-10	2021-03-10	4500000	paid
2988	81	2021-03-03	cash	2021-03-10	2021-04-10	4500000	paid
2989	81	2021-04-03	cash	2021-04-10	2021-05-10	4500000	paid
2990	81	2021-05-03	cash	2021-05-10	2021-06-10	4500000	paid
2991	81	2021-06-03	cash	2021-06-10	2021-07-10	4500000	paid
2992	81	2021-07-03	cash	2021-07-10	2021-08-10	4500000	paid
2993	81	2021-08-03	cash	2021-08-10	2021-09-10	4500000	paid
2994	81	2021-09-03	cash	2021-09-10	2021-10-10	4500000	paid
2995	81	2021-10-03	cash	2021-10-10	2021-11-10	4500000	paid
2996	81	2021-11-03	cash	2021-11-10	2021-12-10	4500000	paid
2997	81	2021-12-03	cash	2021-12-10	2022-01-10	4500000	paid
2998	81	2022-01-03	cash	2022-01-10	2022-02-10	4500000	paid
2999	81	2022-02-03	cash	2022-02-10	2022-03-10	4500000	paid
3000	81	2022-03-03	cash	2022-03-10	2022-04-10	4500000	paid
3001	82	2022-11-19	cash	2022-11-26	2022-12-26	7900000	paid
3013	83	2019-10-22	cash	2019-10-29	2019-11-29	1400000	paid
3014	83	2019-11-22	cash	2019-11-29	2019-12-29	1400000	paid
3015	83	2019-12-22	cash	2019-12-29	2020-01-29	1400000	paid
3016	83	2020-01-22	cash	2020-01-29	2020-02-29	1400000	paid
3017	83	2020-02-22	cash	2020-02-29	2020-03-29	1400000	paid
3018	83	2020-03-22	cash	2020-03-29	2020-04-29	1400000	paid
3019	83	2020-04-22	cash	2020-04-29	2020-05-29	1400000	paid
3020	83	2020-05-22	cash	2020-05-29	2020-06-29	1400000	paid
3021	83	2020-06-22	cash	2020-06-29	2020-07-29	1400000	paid
3022	83	2020-07-22	cash	2020-07-29	2020-08-29	1400000	paid
3023	83	2020-08-22	cash	2020-08-29	2020-09-29	1400000	paid
3024	83	2020-09-22	cash	2020-09-29	2020-10-29	1400000	paid
3025	84	2022-08-31	cash	2022-09-07	2022-10-07	2400000	paid
3026	84	2022-09-30	cash	2022-10-07	2022-11-07	2400000	paid
3027	84	2022-10-31	cash	2022-11-07	2022-12-07	2400000	paid
3073	85	2021-06-21	cash	2021-06-28	2021-07-28	2900000	paid
3074	85	2021-07-21	cash	2021-07-28	2021-08-28	2900000	paid
3075	85	2021-08-21	cash	2021-08-28	2021-09-28	2900000	paid
3076	85	2021-09-21	cash	2021-09-28	2021-10-28	2900000	paid
3077	85	2021-10-21	cash	2021-10-28	2021-11-28	2900000	paid
3078	85	2021-11-21	cash	2021-11-28	2021-12-28	2900000	paid
3079	85	2021-12-21	cash	2021-12-28	2022-01-28	2900000	paid
3080	85	2022-01-21	cash	2022-01-28	2022-02-28	2900000	paid
3081	85	2022-02-21	cash	2022-02-28	2022-03-28	2900000	paid
3082	85	2022-03-21	cash	2022-03-28	2022-04-28	2900000	paid
3083	85	2022-04-21	cash	2022-04-28	2022-05-28	2900000	paid
3084	85	2022-05-21	cash	2022-05-28	2022-06-28	2900000	paid
3085	85	2022-06-21	cash	2022-06-28	2022-07-28	2900000	paid
3086	85	2022-07-21	cash	2022-07-28	2022-08-28	2900000	paid
3087	85	2022-08-21	cash	2022-08-28	2022-09-28	2900000	paid
3088	85	2022-09-21	cash	2022-09-28	2022-10-28	2900000	paid
3089	85	2022-10-21	cash	2022-10-28	2022-11-28	2900000	paid
3090	85	2022-11-21	cash	2022-11-28	2022-12-28	2900000	paid
3133	86	2018-06-30	cash	2018-07-07	2018-08-07	7000000	paid
3134	86	2018-07-31	cash	2018-08-07	2018-09-07	7000000	paid
3135	86	2018-08-31	cash	2018-09-07	2018-10-07	7000000	paid
3136	86	2018-09-30	cash	2018-10-07	2018-11-07	7000000	paid
3137	86	2018-10-31	cash	2018-11-07	2018-12-07	7000000	paid
3138	86	2018-11-30	cash	2018-12-07	2019-01-07	7000000	paid
3139	86	2018-12-31	cash	2019-01-07	2019-02-07	7000000	paid
3140	86	2019-01-31	cash	2019-02-07	2019-03-07	7000000	paid
3141	86	2019-02-28	cash	2019-03-07	2019-04-07	7000000	paid
3142	86	2019-03-31	cash	2019-04-07	2019-05-07	7000000	paid
3143	86	2019-04-30	cash	2019-05-07	2019-06-07	7000000	paid
3144	86	2019-05-31	cash	2019-06-07	2019-07-07	7000000	paid
3145	86	2019-06-30	cash	2019-07-07	2019-08-07	7000000	paid
3146	86	2019-07-31	cash	2019-08-07	2019-09-07	7000000	paid
3147	86	2019-08-31	cash	2019-09-07	2019-10-07	7000000	paid
3148	86	2019-09-30	cash	2019-10-07	2019-11-07	7000000	paid
3149	86	2019-10-31	cash	2019-11-07	2019-12-07	7000000	paid
3150	86	2019-11-30	cash	2019-12-07	2020-01-07	7000000	paid
3151	86	2019-12-31	cash	2020-01-07	2020-02-07	7000000	paid
3152	86	2020-01-31	cash	2020-02-07	2020-03-07	7000000	paid
3153	86	2020-02-29	cash	2020-03-07	2020-04-07	7000000	paid
3154	86	2020-03-31	cash	2020-04-07	2020-05-07	7000000	paid
3155	86	2020-04-30	cash	2020-05-07	2020-06-07	7000000	paid
3280	92	2022-12-07	cash	2022-12-14	2023-01-14	1800000	paid
3281	92	2023-01-07	cash	2023-01-14	2023-02-14	1800000	paid
3368	95	2022-12-06	cash	2022-12-13	2023-01-13	700000	paid
3369	95	2023-01-06	cash	2023-01-13	2023-02-13	700000	paid
3156	86	2020-05-31	cash	2020-06-07	2020-07-07	7000000	paid
3157	86	2020-06-30	cash	2020-07-07	2020-08-07	7000000	paid
3158	86	2020-07-31	cash	2020-08-07	2020-09-07	7000000	paid
3159	86	2020-08-31	cash	2020-09-07	2020-10-07	7000000	paid
3160	86	2020-09-30	cash	2020-10-07	2020-11-07	7000000	paid
3161	86	2020-10-31	cash	2020-11-07	2020-12-07	7000000	paid
3162	86	2020-11-30	cash	2020-12-07	2021-01-07	7000000	paid
3163	86	2020-12-31	cash	2021-01-07	2021-02-07	7000000	paid
3164	86	2021-01-31	cash	2021-02-07	2021-03-07	7000000	paid
3165	86	2021-02-28	cash	2021-03-07	2021-04-07	7000000	paid
3166	86	2021-03-31	cash	2021-04-07	2021-05-07	7000000	paid
3167	86	2021-04-30	cash	2021-05-07	2021-06-07	7000000	paid
3168	86	2021-05-31	cash	2021-06-07	2021-07-07	7000000	paid
3169	86	2021-06-30	cash	2021-07-07	2021-08-07	7000000	paid
3170	86	2021-07-31	cash	2021-08-07	2021-09-07	7000000	paid
3171	86	2021-08-31	cash	2021-09-07	2021-10-07	7000000	paid
3172	86	2021-09-30	cash	2021-10-07	2021-11-07	7000000	paid
3173	86	2021-10-31	cash	2021-11-07	2021-12-07	7000000	paid
3174	86	2021-11-30	cash	2021-12-07	2022-01-07	7000000	paid
3175	86	2021-12-31	cash	2022-01-07	2022-02-07	7000000	paid
3176	86	2022-01-31	cash	2022-02-07	2022-03-07	7000000	paid
3177	86	2022-02-28	cash	2022-03-07	2022-04-07	7000000	paid
3178	86	2022-03-31	cash	2022-04-07	2022-05-07	7000000	paid
3179	86	2022-04-30	cash	2022-05-07	2022-06-07	7000000	paid
3180	86	2022-05-31	cash	2022-06-07	2022-07-07	7000000	paid
3181	86	2022-06-30	cash	2022-07-07	2022-08-07	7000000	paid
3182	86	2022-07-31	cash	2022-08-07	2022-09-07	7000000	paid
3183	86	2022-08-31	cash	2022-09-07	2022-10-07	7000000	paid
3184	86	2022-09-30	cash	2022-10-07	2022-11-07	7000000	paid
3185	86	2022-10-31	cash	2022-11-07	2022-12-07	7000000	paid
3193	87	2022-04-30	cash	2022-05-07	2022-06-07	400000	paid
3194	87	2022-05-31	cash	2022-06-07	2022-07-07	400000	paid
3195	87	2022-06-30	cash	2022-07-07	2022-08-07	400000	paid
3196	87	2022-07-31	cash	2022-08-07	2022-09-07	400000	paid
3197	87	2022-08-31	cash	2022-09-07	2022-10-07	400000	paid
3198	87	2022-09-30	cash	2022-10-07	2022-11-07	400000	paid
3199	87	2022-10-31	cash	2022-11-07	2022-12-07	400000	paid
3217	88	2021-05-09	cash	2021-05-16	2021-06-16	3000000	paid
3218	88	2021-06-09	cash	2021-06-16	2021-07-16	3000000	paid
3219	88	2021-07-09	cash	2021-07-16	2021-08-16	3000000	paid
3220	88	2021-08-09	cash	2021-08-16	2021-09-16	3000000	paid
3221	88	2021-09-09	cash	2021-09-16	2021-10-16	3000000	paid
3222	88	2021-10-09	cash	2021-10-16	2021-11-16	3000000	paid
3223	88	2021-11-09	cash	2021-11-16	2021-12-16	3000000	paid
3224	88	2021-12-09	cash	2021-12-16	2022-01-16	3000000	paid
3225	88	2022-01-09	cash	2022-01-16	2022-02-16	3000000	paid
3226	88	2022-02-09	cash	2022-02-16	2022-03-16	3000000	paid
3227	88	2022-03-09	cash	2022-03-16	2022-04-16	3000000	paid
3228	88	2022-04-09	cash	2022-04-16	2022-05-16	3000000	paid
3229	89	2020-02-27	cash	2020-03-05	2020-04-05	7500000	paid
3230	89	2020-03-29	cash	2020-04-05	2020-05-05	7500000	paid
3231	89	2020-04-28	cash	2020-05-05	2020-06-05	7500000	paid
3232	89	2020-05-29	cash	2020-06-05	2020-07-05	7500000	paid
3233	89	2020-06-28	cash	2020-07-05	2020-08-05	7500000	paid
3234	89	2020-07-29	cash	2020-08-05	2020-09-05	7500000	paid
3235	89	2020-08-29	cash	2020-09-05	2020-10-05	7500000	paid
3236	89	2020-09-28	cash	2020-10-05	2020-11-05	7500000	paid
3237	89	2020-10-29	cash	2020-11-05	2020-12-05	7500000	paid
3238	89	2020-11-28	cash	2020-12-05	2021-01-05	7500000	paid
3239	89	2020-12-29	cash	2021-01-05	2021-02-05	7500000	paid
3240	89	2021-01-29	cash	2021-02-05	2021-03-05	7500000	paid
3241	90	2019-01-15	cash	2019-01-22	2019-02-22	6600000	paid
3242	90	2019-02-15	cash	2019-02-22	2019-03-22	6600000	paid
3243	90	2019-03-15	cash	2019-03-22	2019-04-22	6600000	paid
3244	90	2019-04-15	cash	2019-04-22	2019-05-22	6600000	paid
3245	90	2019-05-15	cash	2019-05-22	2019-06-22	6600000	paid
3246	90	2019-06-15	cash	2019-06-22	2019-07-22	6600000	paid
3247	90	2019-07-15	cash	2019-07-22	2019-08-22	6600000	paid
3248	90	2019-08-15	cash	2019-08-22	2019-09-22	6600000	paid
3249	90	2019-09-15	cash	2019-09-22	2019-10-22	6600000	paid
3250	90	2019-10-15	cash	2019-10-22	2019-11-22	6600000	paid
3251	90	2019-11-15	cash	2019-11-22	2019-12-22	6600000	paid
3252	90	2019-12-15	cash	2019-12-22	2020-01-22	6600000	paid
3253	90	2020-01-15	cash	2020-01-22	2020-02-22	6600000	paid
3254	90	2020-02-15	cash	2020-02-22	2020-03-22	6600000	paid
3255	90	2020-03-15	cash	2020-03-22	2020-04-22	6600000	paid
3256	90	2020-04-15	cash	2020-04-22	2020-05-22	6600000	paid
3257	90	2020-05-15	cash	2020-05-22	2020-06-22	6600000	paid
3258	90	2020-06-15	cash	2020-06-22	2020-07-22	6600000	paid
3259	90	2020-07-15	cash	2020-07-22	2020-08-22	6600000	paid
3260	90	2020-08-15	cash	2020-08-22	2020-09-22	6600000	paid
3261	90	2020-09-15	cash	2020-09-22	2020-10-22	6600000	paid
3262	90	2020-10-15	cash	2020-10-22	2020-11-22	6600000	paid
3263	90	2020-11-15	cash	2020-11-22	2020-12-22	6600000	paid
3264	90	2020-12-15	cash	2020-12-22	2021-01-22	6600000	paid
3265	91	2019-10-01	cash	2019-10-08	2019-11-08	8100000	paid
3266	91	2019-11-01	cash	2019-11-08	2019-12-08	8100000	paid
3267	91	2019-12-01	cash	2019-12-08	2020-01-08	8100000	paid
3268	91	2020-01-01	cash	2020-01-08	2020-02-08	8100000	paid
3269	91	2020-02-01	cash	2020-02-08	2020-03-08	8100000	paid
3409	96	2022-12-24	cash	2022-12-31	2023-01-31	8700000	paid
3410	96	2023-01-24	cash	2023-01-31	2023-02-28	8700000	paid
3536	98	2022-12-01	cash	2022-12-08	2023-01-08	4500000	paid
3270	91	2020-03-01	cash	2020-03-08	2020-04-08	8100000	paid
3271	91	2020-04-01	cash	2020-04-08	2020-05-08	8100000	paid
3272	91	2020-05-01	cash	2020-05-08	2020-06-08	8100000	paid
3273	91	2020-06-01	cash	2020-06-08	2020-07-08	8100000	paid
3274	91	2020-07-01	cash	2020-07-08	2020-08-08	8100000	paid
3275	91	2020-08-01	cash	2020-08-08	2020-09-08	8100000	paid
3276	91	2020-09-01	cash	2020-09-08	2020-10-08	8100000	paid
3277	92	2022-09-07	cash	2022-09-14	2022-10-14	1800000	paid
3278	92	2022-10-07	cash	2022-10-14	2022-11-14	1800000	paid
3279	92	2022-11-07	cash	2022-11-14	2022-12-14	1800000	paid
3289	93	2019-01-10	cash	2019-01-17	2019-02-17	5200000	paid
3290	93	2019-02-10	cash	2019-02-17	2019-03-17	5200000	paid
3291	93	2019-03-10	cash	2019-03-17	2019-04-17	5200000	paid
3292	93	2019-04-10	cash	2019-04-17	2019-05-17	5200000	paid
3293	93	2019-05-10	cash	2019-05-17	2019-06-17	5200000	paid
3294	93	2019-06-10	cash	2019-06-17	2019-07-17	5200000	paid
3295	93	2019-07-10	cash	2019-07-17	2019-08-17	5200000	paid
3296	93	2019-08-10	cash	2019-08-17	2019-09-17	5200000	paid
3297	93	2019-09-10	cash	2019-09-17	2019-10-17	5200000	paid
3298	93	2019-10-10	cash	2019-10-17	2019-11-17	5200000	paid
3299	93	2019-11-10	cash	2019-11-17	2019-12-17	5200000	paid
3300	93	2019-12-10	cash	2019-12-17	2020-01-17	5200000	paid
3301	93	2020-01-10	cash	2020-01-17	2020-02-17	5200000	paid
3302	93	2020-02-10	cash	2020-02-17	2020-03-17	5200000	paid
3303	93	2020-03-10	cash	2020-03-17	2020-04-17	5200000	paid
3304	93	2020-04-10	cash	2020-04-17	2020-05-17	5200000	paid
3305	93	2020-05-10	cash	2020-05-17	2020-06-17	5200000	paid
3306	93	2020-06-10	cash	2020-06-17	2020-07-17	5200000	paid
3307	93	2020-07-10	cash	2020-07-17	2020-08-17	5200000	paid
3308	93	2020-08-10	cash	2020-08-17	2020-09-17	5200000	paid
3309	93	2020-09-10	cash	2020-09-17	2020-10-17	5200000	paid
3310	93	2020-10-10	cash	2020-10-17	2020-11-17	5200000	paid
3311	93	2020-11-10	cash	2020-11-17	2020-12-17	5200000	paid
3312	93	2020-12-10	cash	2020-12-17	2021-01-17	5200000	paid
3313	93	2021-01-10	cash	2021-01-17	2021-02-17	5200000	paid
3314	93	2021-02-10	cash	2021-02-17	2021-03-17	5200000	paid
3315	93	2021-03-10	cash	2021-03-17	2021-04-17	5200000	paid
3316	93	2021-04-10	cash	2021-04-17	2021-05-17	5200000	paid
3317	93	2021-05-10	cash	2021-05-17	2021-06-17	5200000	paid
3318	93	2021-06-10	cash	2021-06-17	2021-07-17	5200000	paid
3319	93	2021-07-10	cash	2021-07-17	2021-08-17	5200000	paid
3320	93	2021-08-10	cash	2021-08-17	2021-09-17	5200000	paid
3321	93	2021-09-10	cash	2021-09-17	2021-10-17	5200000	paid
3322	93	2021-10-10	cash	2021-10-17	2021-11-17	5200000	paid
3323	93	2021-11-10	cash	2021-11-17	2021-12-17	5200000	paid
3324	93	2021-12-10	cash	2021-12-17	2022-01-17	5200000	paid
3325	94	2018-04-21	cash	2018-04-28	2018-05-28	5800000	paid
3326	94	2018-05-21	cash	2018-05-28	2018-06-28	5800000	paid
3327	94	2018-06-21	cash	2018-06-28	2018-07-28	5800000	paid
3328	94	2018-07-21	cash	2018-07-28	2018-08-28	5800000	paid
3329	94	2018-08-21	cash	2018-08-28	2018-09-28	5800000	paid
3330	94	2018-09-21	cash	2018-09-28	2018-10-28	5800000	paid
3331	94	2018-10-21	cash	2018-10-28	2018-11-28	5800000	paid
3332	94	2018-11-21	cash	2018-11-28	2018-12-28	5800000	paid
3333	94	2018-12-21	cash	2018-12-28	2019-01-28	5800000	paid
3334	94	2019-01-21	cash	2019-01-28	2019-02-28	5800000	paid
3335	94	2019-02-21	cash	2019-02-28	2019-03-28	5800000	paid
3336	94	2019-03-21	cash	2019-03-28	2019-04-28	5800000	paid
3337	94	2019-04-21	cash	2019-04-28	2019-05-28	5800000	paid
3338	94	2019-05-21	cash	2019-05-28	2019-06-28	5800000	paid
3339	94	2019-06-21	cash	2019-06-28	2019-07-28	5800000	paid
3340	94	2019-07-21	cash	2019-07-28	2019-08-28	5800000	paid
3341	94	2019-08-21	cash	2019-08-28	2019-09-28	5800000	paid
3342	94	2019-09-21	cash	2019-09-28	2019-10-28	5800000	paid
3343	94	2019-10-21	cash	2019-10-28	2019-11-28	5800000	paid
3344	94	2019-11-21	cash	2019-11-28	2019-12-28	5800000	paid
3345	94	2019-12-21	cash	2019-12-28	2020-01-28	5800000	paid
3346	94	2020-01-21	cash	2020-01-28	2020-02-28	5800000	paid
3347	94	2020-02-21	cash	2020-02-28	2020-03-28	5800000	paid
3348	94	2020-03-21	cash	2020-03-28	2020-04-28	5800000	paid
3349	95	2021-05-06	cash	2021-05-13	2021-06-13	700000	paid
3350	95	2021-06-06	cash	2021-06-13	2021-07-13	700000	paid
3351	95	2021-07-06	cash	2021-07-13	2021-08-13	700000	paid
3352	95	2021-08-06	cash	2021-08-13	2021-09-13	700000	paid
3353	95	2021-09-06	cash	2021-09-13	2021-10-13	700000	paid
3354	95	2021-10-06	cash	2021-10-13	2021-11-13	700000	paid
3537	98	2023-01-01	cash	2023-01-08	2023-02-08	4500000	paid
37	2	2021-04-17	cash	2021-04-24	2021-05-24	4300000	paid
38	2	2021-05-17	cash	2021-05-24	2021-06-24	4300000	paid
39	2	2021-06-17	cash	2021-06-24	2021-07-24	4300000	paid
40	2	2021-07-17	cash	2021-07-24	2021-08-24	4300000	paid
41	2	2021-08-17	cash	2021-08-24	2021-09-24	4300000	paid
42	2	2021-09-17	cash	2021-09-24	2021-10-24	4300000	paid
43	2	2021-10-17	cash	2021-10-24	2021-11-24	4300000	paid
44	2	2021-11-17	cash	2021-11-24	2021-12-24	4300000	paid
45	2	2021-12-17	cash	2021-12-24	2022-01-24	4300000	paid
46	2	2022-01-17	cash	2022-01-24	2022-02-24	4300000	paid
47	2	2022-02-17	cash	2022-02-24	2022-03-24	4300000	paid
48	2	2022-03-17	cash	2022-03-24	2022-04-24	4300000	paid
49	2	2022-04-17	cash	2022-04-24	2022-05-24	4300000	paid
50	2	2022-05-17	cash	2022-05-24	2022-06-24	4300000	paid
51	2	2022-06-17	cash	2022-06-24	2022-07-24	4300000	paid
52	2	2022-07-17	cash	2022-07-24	2022-08-24	4300000	paid
53	2	2022-08-17	cash	2022-08-24	2022-09-24	4300000	paid
54	2	2022-09-17	cash	2022-09-24	2022-10-24	4300000	paid
55	2	2022-10-17	cash	2022-10-24	2022-11-24	4300000	paid
56	2	2022-11-17	cash	2022-11-24	2022-12-24	4300000	paid
97	4	2018-03-08	cash	2018-03-15	2018-04-15	9600000	paid
98	4	2018-04-08	cash	2018-04-15	2018-05-15	9600000	paid
99	4	2018-05-08	cash	2018-05-15	2018-06-15	9600000	paid
3355	95	2021-11-06	cash	2021-11-13	2021-12-13	700000	paid
3356	95	2021-12-06	cash	2021-12-13	2022-01-13	700000	paid
3357	95	2022-01-06	cash	2022-01-13	2022-02-13	700000	paid
3358	95	2022-02-06	cash	2022-02-13	2022-03-13	700000	paid
3359	95	2022-03-06	cash	2022-03-13	2022-04-13	700000	paid
3360	95	2022-04-06	cash	2022-04-13	2022-05-13	700000	paid
3361	95	2022-05-06	cash	2022-05-13	2022-06-13	700000	paid
3362	95	2022-06-06	cash	2022-06-13	2022-07-13	700000	paid
3363	95	2022-07-06	cash	2022-07-13	2022-08-13	700000	paid
3364	95	2022-08-06	cash	2022-08-13	2022-09-13	700000	paid
3365	95	2022-09-06	cash	2022-09-13	2022-10-13	700000	paid
3366	95	2022-10-06	cash	2022-10-13	2022-11-13	700000	paid
3367	95	2022-11-06	cash	2022-11-13	2022-12-13	700000	paid
3457	97	2019-06-11	cash	2019-06-18	2019-07-18	3500000	paid
3458	97	2019-07-11	cash	2019-07-18	2019-08-18	3500000	paid
3459	97	2019-08-11	cash	2019-08-18	2019-09-18	3500000	paid
3460	97	2019-09-11	cash	2019-09-18	2019-10-18	3500000	paid
3461	97	2019-10-11	cash	2019-10-18	2019-11-18	3500000	paid
3462	97	2019-11-11	cash	2019-11-18	2019-12-18	3500000	paid
3463	97	2019-12-11	cash	2019-12-18	2020-01-18	3500000	paid
3464	97	2020-01-11	cash	2020-01-18	2020-02-18	3500000	paid
3465	97	2020-02-11	cash	2020-02-18	2020-03-18	3500000	paid
3466	97	2020-03-11	cash	2020-03-18	2020-04-18	3500000	paid
3467	97	2020-04-11	cash	2020-04-18	2020-05-18	3500000	paid
3468	97	2020-05-11	cash	2020-05-18	2020-06-18	3500000	paid
3469	97	2020-06-11	cash	2020-06-18	2020-07-18	3500000	paid
3470	97	2020-07-11	cash	2020-07-18	2020-08-18	3500000	paid
3471	97	2020-08-11	cash	2020-08-18	2020-09-18	3500000	paid
3472	97	2020-09-11	cash	2020-09-18	2020-10-18	3500000	paid
3473	97	2020-10-11	cash	2020-10-18	2020-11-18	3500000	paid
3474	97	2020-11-11	cash	2020-11-18	2020-12-18	3500000	paid
3475	97	2020-12-11	cash	2020-12-18	2021-01-18	3500000	paid
3476	97	2021-01-11	cash	2021-01-18	2021-02-18	3500000	paid
3477	97	2021-02-11	cash	2021-02-18	2021-03-18	3500000	paid
3478	97	2021-03-11	cash	2021-03-18	2021-04-18	3500000	paid
3479	97	2021-04-11	cash	2021-04-18	2021-05-18	3500000	paid
3480	97	2021-05-11	cash	2021-05-18	2021-06-18	3500000	paid
3481	97	2021-06-11	cash	2021-06-18	2021-07-18	3500000	paid
3482	97	2021-07-11	cash	2021-07-18	2021-08-18	3500000	paid
3483	97	2021-08-11	cash	2021-08-18	2021-09-18	3500000	paid
3484	97	2021-09-11	cash	2021-09-18	2021-10-18	3500000	paid
3485	97	2021-10-11	cash	2021-10-18	2021-11-18	3500000	paid
3486	97	2021-11-11	cash	2021-11-18	2021-12-18	3500000	paid
3487	97	2021-12-11	cash	2021-12-18	2022-01-18	3500000	paid
3488	97	2022-01-11	cash	2022-01-18	2022-02-18	3500000	paid
3489	97	2022-02-11	cash	2022-02-18	2022-03-18	3500000	paid
3490	97	2022-03-11	cash	2022-03-18	2022-04-18	3500000	paid
3491	97	2022-04-11	cash	2022-04-18	2022-05-18	3500000	paid
3492	97	2022-05-11	cash	2022-05-18	2022-06-18	3500000	paid
3493	98	2019-05-01	cash	2019-05-08	2019-06-08	4500000	paid
3494	98	2019-06-01	cash	2019-06-08	2019-07-08	4500000	paid
3495	98	2019-07-01	cash	2019-07-08	2019-08-08	4500000	paid
3496	98	2019-08-01	cash	2019-08-08	2019-09-08	4500000	paid
3497	98	2019-09-01	cash	2019-09-08	2019-10-08	4500000	paid
3498	98	2019-10-01	cash	2019-10-08	2019-11-08	4500000	paid
3499	98	2019-11-01	cash	2019-11-08	2019-12-08	4500000	paid
3500	98	2019-12-01	cash	2019-12-08	2020-01-08	4500000	paid
3501	98	2020-01-01	cash	2020-01-08	2020-02-08	4500000	paid
3502	98	2020-02-01	cash	2020-02-08	2020-03-08	4500000	paid
3503	98	2020-03-01	cash	2020-03-08	2020-04-08	4500000	paid
3504	98	2020-04-01	cash	2020-04-08	2020-05-08	4500000	paid
3505	98	2020-05-01	cash	2020-05-08	2020-06-08	4500000	paid
3506	98	2020-06-01	cash	2020-06-08	2020-07-08	4500000	paid
3507	98	2020-07-01	cash	2020-07-08	2020-08-08	4500000	paid
3508	98	2020-08-01	cash	2020-08-08	2020-09-08	4500000	paid
3509	98	2020-09-01	cash	2020-09-08	2020-10-08	4500000	paid
3510	98	2020-10-01	cash	2020-10-08	2020-11-08	4500000	paid
3511	98	2020-11-01	cash	2020-11-08	2020-12-08	4500000	paid
3512	98	2020-12-01	cash	2020-12-08	2021-01-08	4500000	paid
3513	98	2021-01-01	cash	2021-01-08	2021-02-08	4500000	paid
3514	98	2021-02-01	cash	2021-02-08	2021-03-08	4500000	paid
3515	98	2021-03-01	cash	2021-03-08	2021-04-08	4500000	paid
3516	98	2021-04-01	cash	2021-04-08	2021-05-08	4500000	paid
3517	98	2021-05-01	cash	2021-05-08	2021-06-08	4500000	paid
3518	98	2021-06-01	cash	2021-06-08	2021-07-08	4500000	paid
3519	98	2021-07-01	cash	2021-07-08	2021-08-08	4500000	paid
3520	98	2021-08-01	cash	2021-08-08	2021-09-08	4500000	paid
3521	98	2021-09-01	cash	2021-09-08	2021-10-08	4500000	paid
3522	98	2021-10-01	cash	2021-10-08	2021-11-08	4500000	paid
3523	98	2021-11-01	cash	2021-11-08	2021-12-08	4500000	paid
3524	98	2021-12-01	cash	2021-12-08	2022-01-08	4500000	paid
3525	98	2022-01-01	cash	2022-01-08	2022-02-08	4500000	paid
3526	98	2022-02-01	cash	2022-02-08	2022-03-08	4500000	paid
3527	98	2022-03-01	cash	2022-03-08	2022-04-08	4500000	paid
3528	98	2022-04-01	cash	2022-04-08	2022-05-08	4500000	paid
3529	98	2022-05-01	cash	2022-05-08	2022-06-08	4500000	paid
3530	98	2022-06-01	cash	2022-06-08	2022-07-08	4500000	paid
3531	98	2022-07-01	cash	2022-07-08	2022-08-08	4500000	paid
3532	98	2022-08-01	cash	2022-08-08	2022-09-08	4500000	paid
3533	98	2022-09-01	cash	2022-09-08	2022-10-08	4500000	paid
3534	98	2022-10-01	cash	2022-10-08	2022-11-08	4500000	paid
3535	98	2022-11-01	cash	2022-11-08	2022-12-08	4500000	paid
3541	99	2018-03-09	cash	2018-03-16	2018-04-16	8500000	paid
3542	99	2018-04-09	cash	2018-04-16	2018-05-16	8500000	paid
3543	99	2018-05-09	cash	2018-05-16	2018-06-16	8500000	paid
3544	99	2018-06-09	cash	2018-06-16	2018-07-16	8500000	paid
3545	99	2018-07-09	cash	2018-07-16	2018-08-16	8500000	paid
3546	99	2018-08-09	cash	2018-08-16	2018-09-16	8500000	paid
3547	99	2018-09-09	cash	2018-09-16	2018-10-16	8500000	paid
3548	99	2018-10-09	cash	2018-10-16	2018-11-16	8500000	paid
3549	99	2018-11-09	cash	2018-11-16	2018-12-16	8500000	paid
3550	99	2018-12-09	cash	2018-12-16	2019-01-16	8500000	paid
3551	99	2019-01-09	cash	2019-01-16	2019-02-16	8500000	paid
3552	99	2019-02-09	cash	2019-02-16	2019-03-16	8500000	paid
3553	99	2019-03-09	cash	2019-03-16	2019-04-16	8500000	paid
3554	99	2019-04-09	cash	2019-04-16	2019-05-16	8500000	paid
3555	99	2019-05-09	cash	2019-05-16	2019-06-16	8500000	paid
3556	99	2019-06-09	cash	2019-06-16	2019-07-16	8500000	paid
3557	99	2019-07-09	cash	2019-07-16	2019-08-16	8500000	paid
3558	99	2019-08-09	cash	2019-08-16	2019-09-16	8500000	paid
3559	99	2019-09-09	cash	2019-09-16	2019-10-16	8500000	paid
3560	99	2019-10-09	cash	2019-10-16	2019-11-16	8500000	paid
3561	99	2019-11-09	cash	2019-11-16	2019-12-16	8500000	paid
3562	99	2019-12-09	cash	2019-12-16	2020-01-16	8500000	paid
3563	99	2020-01-09	cash	2020-01-16	2020-02-16	8500000	paid
3564	99	2020-02-09	cash	2020-02-16	2020-03-16	8500000	paid
\.


--
-- Data for Name: occupants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.occupants (occupant_id, tenant_id, last_name, first_name, id_card, phone_number) FROM stdin;
1	2	Veltmann	Emilee	2700 2278 0558	187-139-2488
2	3	Demangeon	Lorena	5069 9321 9395	919-829-3490
3	4	Cornew	Hoyt	0847 4492 5300	442-350-4259
4	5	Plaide	Obediah	7542 9171 8924	773-234-6615
5	6	Redman	Kennedy	5572 0237 3341	678-106-7090
6	7	Brookzie	Darill	1335 9794 0677	738-489-2683
7	8	Caley	Corilla	7427 4552 3079	357-429-3144
8	9	Timby	Steward	6522 4337 0807	605-683-9005
9	10	Alman	Rebekah	2528 3345 7226	351-523-5138
10	11	Gallgher	Vic	5679 2871 7355	174-261-8416
11	12	Stidson	Laina	2690 0491 8248	832-636-2989
12	13	Kitley	Hamlen	7950 5790 3044	148-392-3918
13	14	Patise	Freddy	2805 5140 3601	465-964-2813
14	15	Bordman	Clemence	8002 3339 6219	950-563-0099
15	16	Primmer	Simeon	0783 1646 7518	506-228-2331
16	17	Vsanelli	Nichole	6853 1851 2547	727-611-1868
17	18	Cockshtt	Darlene	4903 1480 4087	756-240-7306
18	19	Tellenbroker	Crosby	7192 5791 5055	597-567-9032
19	20	Stelfox	Antonius	6666 6473 8829	562-184-3837
20	21	Gerlack	Fredericka	4347 8307 5410	677-147-4674
21	22	Geillier	Bob	8935 8383 0222	489-825-4514
22	23	Cinnamond	Joya	3491 0979 2607	903-534-8780
23	24	Southwick	Dacey	8141 8229 9012	772-744-2137
24	25	Fielden	Adan	6097 3495 1139	738-955-4822
25	26	Fusco	Gaile	8353 1995 2983	823-323-9466
26	27	Elverston	Seymour	6766 6360 3807	430-565-1745
27	28	Boycott	Antonio	2420 0200 5492	337-710-3362
28	29	Rainy	Shell	6004 4775 6508	266-902-1643
29	30	Hardbattle	Layton	9931 3397 3982	202-820-0837
30	31	Westraw	Lishe	3039 9447 6185	164-884-4678
31	32	Tuley	Goldi	6051 2828 7462	182-311-7734
32	33	Edmead	Vilma	1332 6510 3556	900-360-6563
33	34	Allard	Titus	0708 1287 4854	323-666-3046
34	35	Asmus	Nicola	4122 7245 8250	521-195-3203
35	36	Wilder	Dolph	0957 6563 8101	670-693-3331
36	37	Karpenya	Prudy	1783 5007 5617	297-303-6827
37	38	Cleeve	Bruis	4995 1775 8499	969-649-2039
38	39	Wewell	Horace	1149 3729 7827	937-627-0226
39	40	Ritmeier	Justinian	5781 8234 4365	552-449-4932
40	41	Loweth	Charisse	6216 1524 2719	892-258-0076
41	42	Olman	Porter	1579 1301 2194	461-716-8736
42	43	Spincke	Hadlee	0091 3525 7627	450-116-7322
43	44	Carnoghan	Mel	3665 0131 0289	110-484-1461
44	45	Rickard	Bonni	7933 0259 6647	542-413-9775
45	46	Casazza	Therine	3160 5783 9141	796-760-9460
46	47	O'Grady	Lothaire	7330 7873 1290	749-565-4864
47	48	Nuss	Jannelle	7653 0503 0405	944-568-3152
48	49	Littlefair	Daveta	6018 6555 8197	424-595-7631
49	50	Andraud	Hilly	0747 3333 0459	339-787-1958
50	51	O' Molan	Torie	8277 2154 9912	314-523-4776
51	52	Tewkesberrie	Wernher	0652 4500 1353	600-584-5955
52	53	Fetteplace	Brice	5684 9539 7660	521-789-5741
53	54	Hillam	Kevin	6205 3925 1475	553-411-5417
54	55	Gorst	Bibbye	0401 3164 8561	998-963-8429
55	56	Iacomini	Cecilla	1780 6692 0746	449-681-8119
56	57	Burkitt	Ferne	2930 8356 4596	154-166-5458
57	58	Vassie	Dud	5129 8571 9273	990-609-6434
58	59	Iacovolo	Kerri	4985 5633 3579	726-136-2688
59	60	Jeaffreson	Yuri	3715 3625 1655	849-467-9270
60	61	Reader	Jemmie	2939 8594 2538	487-449-5317
61	62	Diddams	Darleen	5170 6821 7459	881-272-1625
62	63	McCrudden	Kaspar	3910 7698 5222	316-909-3595
63	64	Sutterby	Guss	8109 9433 2966	748-314-2145
64	65	Eves	Ibby	8005 9099 6255	373-159-4293
65	66	Briscam	Sol	3378 2962 0956	961-764-7495
66	67	Berecloth	Emmalynn	1480 8812 5022	894-881-4162
67	68	Sizzey	Hayward	5830 4975 4970	390-941-9293
68	69	Ramsdale	Adolpho	9367 4784 6525	382-156-0177
69	70	Recher	Kara	5240 6099 6947	821-564-7647
70	71	Trodler	Legra	1042 3790 1004	210-130-5031
71	72	Fairbrace	Jeralee	5712 4500 7588	197-907-8588
72	73	Hawney	Efren	5499 0903 6847	732-740-4514
73	74	Molnar	Zarla	1706 8061 5856	941-875-2482
74	75	Middup	Blanch	5992 9584 0536	773-190-6020
75	76	MacNeilley	Collete	9417 3799 7293	967-943-0427
76	77	Duffin	Auberon	6987 2675 9337	393-868-8397
77	78	Gravett	Constantine	7049 7496 6050	436-166-7494
78	79	Waite	Antons	7488 2169 3103	988-995-5069
79	80	Meggison	Myron	8382 1430 5331	904-967-9976
80	81	Storr	Kare	5971 3908 5313	336-634-0500
81	82	Adey	Jeffie	9471 7407 5033	196-313-1986
82	83	Totaro	Dora	1280 5018 6069	875-745-3536
83	84	Speechley	Cele	7371 4014 7580	745-402-1334
84	85	Litt	Lorrie	0210 8814 2580	727-786-8483
85	86	Lawes	Lennie	9451 2738 5360	984-177-9685
86	87	Simonaitis	Alley	3092 2991 1872	559-395-7412
87	88	Jacson	Drucy	5634 2167 5598	690-646-2490
88	89	Haggerty	Elsi	7010 8837 4065	308-717-5649
89	90	Balaam	Augustus	1139 9406 9357	500-616-9479
90	91	Poundesford	Karrie	3181 8711 0242	392-779-1609
91	92	Gantlett	Tremain	2681 5807 2834	526-176-5549
92	93	Shorto	Trevar	3961 0125 6086	207-847-9055
93	94	Gebhard	Blondelle	2669 0825 6749	303-668-5622
94	95	Botterell	Felicia	6843 7876 1776	138-202-6219
95	96	Elcoate	Virge	2101 5220 9092	591-491-4362
96	97	Anand	Lindsey	7294 5408 1899	675-324-3810
97	98	Sparrow	Eimile	6794 2914 7793	207-736-5836
98	99	Frayling	Codi	4637 3764 1504	676-215-5917
99	100	Arnoll	Worth	5632 3089 8427	763-106-1750
100	2	Fries	Kincaid	7112 4544 1807	498-246-2390
101	3	Llorens	Jacquelin	2227 0474 8237	780-189-9174
102	4	Morot	Claus	8230 6497 2838	668-561-6232
103	5	Handrick	Sonnie	0339 0126 4064	327-616-7899
104	6	McChruiter	Had	2775 2201 4912	260-197-8899
105	7	Gherardi	Lorri	8816 1994 9264	261-406-5709
106	8	Mangeney	Amaleta	2138 4667 5892	600-232-6258
107	9	Ganniclifft	Francesco	2707 8137 5298	988-136-2217
108	10	Eames	Leontine	5785 3104 8244	325-113-4731
109	11	De Wolfe	Colette	1656 0002 5539	588-394-5343
110	12	Roan	Chariot	9843 3572 2422	314-667-5528
111	13	Matejovsky	Munmro	8391 0419 0119	618-137-9862
112	14	Signori	Billi	8612 9498 1492	908-798-0777
113	15	Shildrick	Carlene	4633 7662 9929	912-705-8586
114	16	Ivachyov	Noam	2920 5072 3483	146-214-1489
115	17	Tingly	Alessandro	0839 0636 6989	319-422-5795
116	18	Cow	Cristine	3369 9960 3488	247-785-5351
117	19	Thaller	Tarrah	5472 7202 8259	560-226-6587
118	20	Filshin	Pauly	4427 2524 2442	206-116-3620
119	21	Hoodspeth	Jacques	6390 2208 5241	483-334-6783
120	22	Killik	Hans	0207 9353 5091	549-345-6751
121	23	Mingaud	Kaile	2837 6752 9141	976-110-6070
122	24	Hawyes	Toiboid	5364 4218 3680	995-512-4834
123	25	Teodori	Clarette	4542 6479 5708	429-693-2095
124	26	Ewbank	Tobin	8041 7062 9970	651-426-6437
125	27	Dowdam	Sherwood	1045 3291 5477	417-164-5991
126	28	Maybery	Scotty	6180 3798 0343	559-697-3889
127	29	Blanket	Ariella	7343 5894 8025	555-141-9605
128	30	Willman	Talia	0994 2817 1696	338-319-1692
129	31	MacKartan	Aindrea	0464 4191 1198	139-110-7627
130	32	Layus	Nadine	9686 9598 8210	893-375-7947
131	33	O'Cullinane	Levin	6428 6556 4590	647-132-4388
132	34	Lovett	Damien	7519 1362 8706	751-716-6707
133	35	Peracco	Mick	2553 3093 8216	822-369-0011
134	36	Taynton	Courtnay	9155 6790 3116	492-316-3540
135	37	Blackboro	Alvinia	8211 2511 1906	163-749-7168
136	38	Hulett	Gabriellia	0246 3214 9202	342-649-9103
137	39	Peddel	Mord	3836 2245 2636	599-381-9915
138	40	M'cowis	Cicily	2238 4402 5526	915-316-4974
139	41	Ruddiforth	Kat	6459 8341 7830	829-247-8060
140	42	Rosenwald	Kari	9489 1815 6803	609-919-5298
141	43	Duffrie	Tibold	8136 5566 2614	263-465-3526
142	44	Wimbush	Gaelan	0822 0445 0326	395-424-5018
143	45	Andrick	Constancia	7518 4988 9483	696-792-1948
144	46	Dy	Kathrine	1046 2475 5658	349-846-0540
145	47	Swaden	Philly	2590 7245 5206	302-158-2894
146	48	Fludder	Karrah	6705 5491 6417	562-296-2721
147	49	Wright	Iorgo	4896 7199 5736	871-374-6859
148	50	Donhardt	Vic	9776 9485 1890	354-193-4343
149	51	Hebbard	Kellby	7653 4287 3591	494-461-4342
150	52	Jankovsky	Eugenio	4781 3706 7573	237-524-6856
151	53	Olenov	Ortensia	4134 7074 3458	884-868-4330
152	54	Cay	Aguistin	8811 1416 5146	618-440-9702
153	55	Teasey	Gladys	6008 5441 6674	650-438-6258
154	56	Rayer	Petra	9225 5755 1784	180-638-9410
155	57	Raisbeck	Maddie	0478 0014 7143	800-530-9099
156	58	Marzella	Ricardo	4042 8917 5791	216-284-9838
157	59	Coldbathe	Trisha	7565 8361 6553	901-274-9608
158	60	Thunderchief	Madalyn	9568 1366 9634	203-331-1595
159	61	Tripon	Morgan	4305 7493 6832	357-445-2437
160	62	Crilley	Berget	8610 4573 7618	568-894-3891
161	63	Harries	Loni	8457 1400 6578	239-151-5471
162	64	Howgate	Giuditta	1455 3740 0605	897-935-3828
163	65	Heenan	Alejandro	9309 3286 0817	322-862-1562
164	66	Greet	Tania	5917 6358 4498	718-577-2124
165	67	Heddy	Merla	5633 4365 8471	529-348-5641
166	68	Ciotto	Jemimah	9026 4929 5451	260-448-2299
167	69	Milberry	Conan	1144 6474 0012	976-109-5388
168	70	Scripture	Ki	8887 6002 8278	926-268-8399
169	71	Kinastan	Gilligan	9884 5802 5539	930-320-2956
170	72	O'Sheeryne	Griswold	1042 2749 3173	625-101-1551
171	73	Blakely	Katherina	8095 8807 2488	291-407-4726
172	74	Toffalo	Derward	0076 7579 6978	840-572-2297
173	75	Petyanin	Sigismund	0597 5729 2491	719-487-8232
174	76	Ronald	Crystie	1573 0850 0333	384-868-2992
175	77	Losty	Martguerita	9200 6578 7328	468-256-4715
176	78	Rickword	Hanny	5784 4291 7445	792-119-3921
177	79	Sillis	Tann	2986 9922 7148	980-465-5100
178	80	Faltin	Sabrina	5484 7346 4098	193-702-2696
179	81	Cradock	Carlye	2191 2994 5432	296-753-7808
180	82	Emslie	Avril	6328 5572 9661	940-473-2289
181	83	Moyse	Chan	6668 4079 1205	607-792-7585
182	84	Baroch	Lenora	1678 6999 9565	102-453-1468
183	85	Muccino	Diane-marie	2675 9208 8158	438-903-4027
184	86	Hablot	Tania	4061 9969 5026	400-348-1817
185	87	Nutter	Ysabel	1502 2041 1298	918-319-9343
186	88	Fedder	Elvin	0606 6940 1625	151-643-6901
187	89	Carlow	Osborn	4136 1364 1633	356-225-3961
188	90	Ilsley	Adriana	7106 4103 6045	827-239-4318
189	91	Lafayette	Austina	8334 9321 4079	874-811-9071
190	92	Jerrom	Worthington	7809 9409 6616	336-841-7515
191	93	Skoggins	Freida	2225 9623 5691	688-506-1199
192	94	Moline	Daveta	0155 5892 9235	945-419-2498
193	95	Lilleyman	Saxon	4645 3109 2693	156-189-9263
194	96	Barron	Tobey	5108 1834 7854	983-900-6386
195	97	Beament	Arnoldo	5481 4681 1074	440-341-6238
196	98	Wrack	Alverta	2722 2671 0315	377-774-2001
197	99	Ealden	Salvatore	2282 4680 8875	241-638-4036
198	100	Robart	Sindee	9237 7681 9710	974-947-8988
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (role_id, role_name) FROM stdin;
1	admin 
2	service manager
3	tenant
\.


--
-- Data for Name: service_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_categories (service_id, service_category_id, service_category_name, price, note) FROM stdin;
1	1	weekly	10	abcd
1	2	monthly	40	abcd
1	3	yearly	70	abcd
2	4	weekly	20	abcd
2	5	monthly	50	abcd
2	6	yearly	80	abcd
3	7	weekly	30	abcd
3	8	monthly	60	abcd
3	9	yearly	90	abcd
\.


--
-- Data for Name: service_contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_contracts (service_contract_id, tenant_id, service_category_id, payment_date, start_date, end_date, quantity, fee, status) FROM stdin;
1	1	7	\N	2022-05-05	2024-10-05	5	450	active
2	3	6	\N	2022-07-11	2023-11-11	5	346	active
3	6	1	\N	2022-04-04	2023-03-04	2	297	active
4	11	7	\N	2022-03-26	2024-01-26	5	238	active
5	14	9	\N	2022-11-26	2024-02-26	3	341	active
6	16	2	\N	2022-07-19	2023-08-19	3	246	active
7	18	5	\N	2022-07-15	2024-12-15	1	385	active
8	20	3	\N	2022-10-09	2025-02-09	4	126	active
9	23	1	\N	2022-08-11	2024-08-11	3	106	active
10	25	5	\N	2022-07-14	2024-08-14	3	365	active
11	26	6	\N	2022-04-22	2023-12-22	4	160	active
12	29	9	\N	2022-07-01	2024-08-01	1	400	active
13	35	3	\N	2022-03-07	2023-10-07	2	164	active
14	36	2	\N	2022-11-23	2024-04-23	2	488	active
15	37	9	\N	2022-09-18	2025-05-18	2	485	active
16	38	4	\N	2022-03-09	2024-12-09	3	397	active
17	39	3	\N	2022-06-14	2023-03-14	1	333	active
18	43	2	\N	2022-11-23	2025-03-23	2	158	active
19	45	6	\N	2022-06-25	2024-08-25	2	461	active
20	46	1	\N	2022-12-27	2024-01-27	2	141	active
21	49	3	\N	2022-11-19	2024-11-19	2	188	active
22	53	4	\N	2022-08-28	2024-07-28	4	198	active
23	54	5	\N	2022-11-15	2023-06-15	4	498	active
24	57	6	\N	2022-08-04	2024-10-04	1	335	active
25	62	3	\N	2022-08-27	2023-12-27	5	285	active
26	70	2	\N	2023-01-16	2025-02-16	5	188	active
27	72	1	\N	2022-07-01	2024-05-01	3	443	active
28	79	2	\N	2022-09-12	2025-05-12	4	310	active
29	84	9	\N	2022-05-25	2025-05-25	3	350	active
30	85	8	\N	2022-10-05	2023-11-05	2	106	active
31	95	8	\N	2022-12-01	2025-07-01	4	456	active
32	96	9	\N	2022-02-18	2023-05-18	4	202	active
33	100	9	\N	2022-01-27	2023-02-27	1	422	active
34	1	7	\N	2022-07-29	2025-04-29	4	208	active
35	3	3	\N	2022-08-28	2024-12-28	5	122	active
36	6	5	\N	2022-12-30	2025-09-30	1	479	active
37	10	8	\N	2022-05-19	2023-10-19	1	466	active
38	11	7	\N	2022-10-13	2023-08-13	1	324	active
39	12	6	\N	2022-08-17	2023-09-17	3	435	active
40	14	3	\N	2022-10-30	2023-02-28	3	194	active
41	16	2	\N	2022-10-31	2023-10-31	3	463	active
42	18	8	\N	2022-08-03	2023-07-03	4	497	active
43	20	6	\N	2022-12-05	2024-08-05	2	334	active
44	23	2	\N	2022-07-27	2024-11-27	5	135	active
45	26	7	\N	2022-06-21	2025-06-21	3	204	active
46	29	6	\N	2022-10-28	2023-09-28	4	206	active
47	35	5	\N	2022-04-18	2024-06-18	5	259	active
48	37	2	\N	2022-12-09	2025-09-09	2	162	active
49	39	3	\N	2022-01-28	2024-03-28	3	456	active
50	43	4	\N	2022-09-06	2024-10-06	2	472	active
51	45	4	\N	2022-11-08	2025-02-08	4	370	active
52	46	1	\N	2022-11-09	2023-12-09	2	131	active
53	49	5	\N	2022-08-02	2023-03-02	1	409	active
54	55	1	\N	2022-11-14	2024-05-14	1	284	active
55	57	9	\N	2022-06-16	2024-11-16	1	262	active
56	58	6	\N	2022-05-10	2023-06-10	5	135	active
57	62	3	\N	2022-02-11	2024-05-11	2	251	active
58	72	1	\N	2022-02-07	2025-02-07	1	363	active
59	75	8	\N	2022-11-01	2024-05-01	4	458	active
60	84	6	\N	2022-09-03	2025-02-03	5	468	active
61	85	2	\N	2022-12-03	2025-09-03	4	286	active
62	95	8	\N	2023-01-06	2024-08-06	4	362	active
63	96	6	\N	2022-12-07	2024-05-07	5	197	active
64	27	9	\N	2022-06-28	2022-11-28	2	245	deactive
65	61	2	\N	2022-06-05	2022-10-05	3	114	deactive
66	71	4	\N	2022-03-18	2022-11-18	5	164	deactive
67	75	7	\N	2022-07-03	2022-11-03	4	122	deactive
68	82	4	\N	2022-09-30	2023-01-30	4	151	deactive
69	92	7	\N	2022-08-31	2022-10-31	5	419	deactive
70	5	6	\N	2022-10-19	2023-01-19	4	369	deactive
71	25	1	\N	2022-10-03	2023-01-03	2	282	deactive
72	36	6	\N	2022-01-30	2022-05-30	1	251	deactive
73	38	9	\N	2022-03-12	2022-11-12	2	200	deactive
74	53	6	\N	2022-03-26	2023-01-26	3	365	deactive
75	54	2	\N	2022-07-27	2022-11-27	5	282	deactive
76	56	5	\N	2022-05-25	2022-11-25	5	307	deactive
77	61	8	\N	2022-02-23	2022-04-23	5	368	deactive
78	70	5	\N	2022-06-14	2023-02-14	3	344	deactive
79	78	6	\N	2022-01-23	2022-07-23	3	456	deactive
80	79	5	\N	2022-09-07	2023-02-07	1	106	deactive
81	86	9	\N	2022-08-26	2022-09-26	3	371	deactive
82	88	4	\N	2022-01-19	2022-04-19	2	428	deactive
83	92	4	\N	2022-03-08	2022-10-08	5	490	deactive
84	100	7	\N	2022-07-30	2022-11-30	5	402	deactive
\.


--
-- Data for Name: service_managers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_managers (account_id, service_manager_id, service_id, last_name, first_name, email, phone_number) FROM stdin;
1	1	1	dang	dat	test@gmail.com	12345
2	2	2	pham	nhi	nhi@gmail.com	54321
3	3	3	huy	hoang	hoang@gmail.com	1232
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (service_id, service_name, note) FROM stdin;
1	laundry	  
2	swimming pool	  
3	parking	  
\.


--
-- Data for Name: tenants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tenants (tenant_id, account_id, last_name, first_name, id_card, email, phone_number) FROM stdin;
1	5	Dat	Dang	1202008629	ddcao2812@gmail.com	369355895
2	6	Jarley	Randee	3564 1561 8313	rjarley0@auda.org.au	654-362-4967
3	7	Ferran	Constantia	4024 2869 1329	cferran2@unesco.org	708-828-6944
4	8	Souch	Ewen	8174 3450 8870	esouch3@studiopress.com	151-377-2068
5	9	Bowart	Cindi	7144 5436 5571	cbowart4@miibeian.gov.cn	242-374-2957
6	10	La Batie	Khalil	0195 3172 1389	klabatie5@over-blog.com	570-355-9210
7	11	Staniford	Alisha	5665 9394 8440	astaniford6@theatlantic.com	727-830-8011
8	12	Hambleton	Cad	8752 0450 1528	chambleton7@shop-pro.jp	556-243-2740
9	13	MacKniely	Glenn	0661 8417 6478	gmackniely8@nytimes.com	323-118-8206
10	14	Dondon	Onida	8393 2848 3511	odondon9@wikispaces.com	935-282-1108
11	15	Kenworthy	Papagena	5575 1828 2624	pkenworthya@skype.com	122-204-8301
12	16	Ellsworthe	Hakeem	3779 7970 6112	hellswortheb@si.edu	861-531-1507
13	17	Treffry	Emmalynn	0155 3184 7986	etreffryc@vinaora.com	888-369-2252
14	18	Leger	Isobel	3479 1804 6577	ilegerd@sun.com	977-859-2622
15	19	Gillies	Kacie	4862 1995 2006	kgilliese@1und1.de	663-410-6295
16	20	Felce	Lani	6729 8726 6208	lfelcef@altervista.org	935-131-0960
17	21	Barthrop	Melvyn	6079 0956 6968	mbarthropg@dailymail.co.uk	792-991-6144
18	22	Battye	Liza	6255 2217 1896	lbattyeh@twitter.com	845-846-5712
19	23	Tappor	Paquito	1802 0792 0405	ptappori@gravatar.com	886-815-6355
20	24	Goundry	Melania	9983 2866 0492	mgoundryj@joomla.org	211-453-2349
21	25	Twelvetrees	Revkah	0092 4042 9422	rtwelvetreesk@lycos.com	758-983-6569
22	26	Collelton	Hort	0637 1873 8127	hcolleltonl@goodreads.com	801-634-8180
23	27	Jenner	Kordula	0311 7620 2036	kjennerm@unblog.fr	690-472-2947
24	28	Fenna	Jillene	3025 5451 4552	jfennan@webeden.co.uk	596-564-9715
25	29	Mora	Ilsa	0650 2095 1432	imorao@amazon.de	155-490-9208
26	30	Bluck	Sybille	7431 3539 6889	sbluckp@icio.us	820-467-8356
27	31	MacWilliam	Jerrie	6980 9421 6998	jmacwilliamq@devhub.com	872-607-1476
28	32	Favill	Willow	6076 1536 2700	wfavillr@purevolume.com	947-666-8322
29	33	Ughelli	Armand	1278 5119 1387	aughellis@wsj.com	313-865-5591
30	34	Rennolds	Rivkah	6667 3656 7059	rrennoldst@github.io	373-215-6989
31	35	Hofer	Lotty	2649 5470 6154	lhoferu@google.pl	607-264-3781
32	36	Gibbeson	Bobby	5623 5049 9656	bgibbesonv@redcross.org	862-761-5407
33	37	Fawdry	Shep	5610 6888 3578	sfawdryw@umich.edu	821-633-0584
34	38	Pidon	Cassey	3222 9236 5793	cpidonx@nasa.gov	964-155-9159
35	39	Layne	Field	5536 9263 7863	flayney@europa.eu	226-671-5237
36	40	Shoobridge	Yardley	4590 7639 2414	yshoobridgez@zimbio.com	190-445-3890
37	41	Buterton	Ora	9353 3898 2024	obuterton10@berkeley.edu	282-181-0866
38	42	Hales	Germaine	2320 3439 0856	ghales11@vk.com	319-485-2797
39	43	Waterhouse	Laney	0202 8219 5143	lwaterhouse12@senate.gov	704-496-8918
40	44	Boodell	Elsa	1948 5374 4027	eboodell13@51.la	513-368-7831
41	45	Chidgey	Elston	0640 3942 2665	echidgey14@nih.gov	229-919-6528
42	46	Cheesworth	Ralina	4258 3978 5718	rcheesworth15@ca.gov	713-295-3627
43	47	Pottie	Melania	4784 1445 7974	mpottie16@symantec.com	358-901-2232
44	48	Gerin	Page	0844 4751 7078	pgerin17@ezinearticles.com	286-244-7707
45	49	Gascoigne	Arney	5009 3059 5808	agascoigne18@chicagotribune.com	932-371-1647
46	50	Saltman	Romola	9948 4356 7695	rsaltman19@tinypic.com	845-446-4320
47	51	Athy	Martino	7142 9569 2951	mathy1a@intel.com	829-471-6402
48	52	Garvill	Ailee	8103 3478 8492	agarvill1b@myspace.com	932-929-1276
49	53	Marchand	Lorianne	1349 7884 6999	lmarchand1c@zdnet.com	366-456-4262
50	54	Alibone	Bridgette	6344 6722 1238	balibone1d@hatena.ne.jp	518-810-2541
51	55	Murrhardt	Solomon	8338 6470 6276	smurrhardt1e@msn.com	283-511-0735
52	56	Capitano	Lane	4447 6965 6096	lcapitano1f@yellowbook.com	356-583-2274
53	57	Iddenden	Cordy	6317 5852 3707	ciddenden1g@elegantthemes.com	337-747-4286
54	58	Praton	Thatch	7138 1503 4144	tpraton1h@clickbank.net	982-306-3121
55	59	Paliser	Brodie	8106 3251 9579	bpaliser1i@princeton.edu	177-841-3899
56	60	Bellon	Derek	8273 9186 0968	dbellon1j@amazon.co.jp	723-736-5188
57	61	Linnell	Claire	2236 3310 1208	clinnell1k@imageshack.us	485-449-1030
58	62	Klinck	Lissa	5372 0521 4571	lklinck1l@twitpic.com	893-500-8344
59	63	Powderham	Jermaine	6341 0120 0533	jpowderham1m@samsung.com	298-611-4147
60	64	Proughten	Dirk	5459 0771 3542	dproughten1n@ft.com	400-388-8034
61	65	Darmody	Tracey	4818 1476 9304	tdarmody1o@gravatar.com	393-389-5178
62	66	Habbin	Christos	4451 4540 9704	chabbin1p@patch.com	238-914-6734
63	67	Wingar	Clayborne	5896 6085 5896	cwingar1q@is.gd	877-713-2629
64	68	Dollman	Gilly	7209 5494 8831	gdollman1r@kickstarter.com	105-611-7648
65	69	Moxham	Engelbert	4528 3936 0851	emoxham1s@ed.gov	739-703-5881
66	70	Robertsson	Nathan	1476 3378 7440	nrobertsson1t@lycos.com	191-569-7310
67	71	Rodgerson	Brigit	6672 9070 6958	brodgerson1u@google.ca	875-317-7740
68	72	Kringe	Sutherlan	8539 8676 6203	skringe1v@yandex.ru	377-201-8586
69	73	Finnis	Barry	9361 3628 8916	bfinnis1w@biblegateway.com	952-190-7145
70	74	Grunnill	Robbert	0243 5994 3385	rgrunnill1x@prweb.com	557-992-6608
71	75	McCloughen	Cairistiona	1374 9698 6738	cmccloughen1y@drupal.org	345-884-4321
72	76	Strickland	Jessie	3165 1922 2013	jstrickland1z@google.co.uk	977-260-5456
73	77	Furness	Kevan	1545 5191 3596	kfurness20@mozilla.com	922-211-5200
74	78	Revely	Kylynn	6367 4546 7894	krevely21@amazon.co.jp	415-289-2226
75	79	Hynard	Ferrel	0565 9679 1307	fhynard22@google.fr	925-421-0186
76	80	Rowat	Auria	7656 6266 9128	arowat23@stumbleupon.com	126-589-0094
77	81	Stiggles	Kerrin	5542 8980 7144	kstiggles24@gnu.org	568-391-5085
78	82	Hannah	Evey	0069 0941 8552	ehannah25@ebay.com	420-276-9220
79	83	Mapples	L;urette	9446 4502 2368	lmapples26@globo.com	554-600-4733
80	84	Ranklin	Sarita	8522 8205 5669	sranklin27@tmall.com	643-916-1023
81	85	Stelli	Hamlin	2943 6022 4183	hstelli28@google.co.uk	561-471-5960
82	86	Hargie	Shellysheldon	7620 1542 3162	shargie29@accuweather.com	212-300-2241
83	87	Kitteman	Madelyn	8241 3916 0296	mkitteman2a@unc.edu	571-769-2004
84	88	Cancellor	Nadia	4583 6185 0257	ncancellor2b@usgs.gov	701-319-8701
85	89	Crew	Marylynne	4291 0198 5944	mcrew2c@tamu.edu	124-576-3650
86	90	Medlin	Cyb	9448 0101 5901	cmedlin2d@4shared.com	976-529-1743
87	91	Cunio	Amery	2456 2806 6273	acunio2e@cisco.com	831-690-2623
88	92	Bealing	Marlow	7352 0613 4692	mbealing2f@accuweather.com	906-735-0719
89	93	Corday	Julianne	3372 3037 8334	jcorday2g@tripadvisor.com	604-360-6366
90	94	Asling	Benyamin	1400 7831 3946	basling2h@booking.com	180-161-5536
91	95	Odeson	Kerry	9016 6441 7686	kodeson2i@utexas.edu	676-551-6033
92	96	Reinhard	Justine	9726 9234 5284	jreinhard2j@nhs.uk	365-848-6272
93	97	Parrington	Deane	2394 9884 0912	dparrington2k@tripod.com	878-132-2073
94	98	Swindall	Tana	6192 4449 1385	tswindall2l@scientificamerican.com	358-496-7828
95	99	Jacomb	Gaylene	4354 7943 6460	gjacomb2m@networksolutions.com	293-850-2727
96	100	Headford	Jeane	0242 1145 0180	jheadford2n@wikia.com	519-319-5388
97	101	Borne	Lianne	2377 8677 6080	lborne2o@quantcast.com	498-629-6370
98	102	Shields	Meghann	4150 1014 0676	mshields2p@homestead.com	858-624-2458
99	103	Jenicke	Clemens	9804 0619 8956	cjenicke2q@weibo.com	380-669-8668
100	104	Butterick	Alan	9168 7388 8664	abutterick2r@theguardian.com	598-340-4063
\.


--
-- Name: accounts_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_account_id_seq', 104, true);


--
-- Name: lease_lease_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lease_lease_id_seq', 99, true);


--
-- Name: lease_payments_lease_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lease_payments_lease_payment_id_seq', 3564, true);


--
-- Name: occupants_occupant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.occupants_occupant_id_seq', 198, true);


--
-- Name: service_categories_service_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_categories_service_category_id_seq', 9, true);


--
-- Name: service_contracts_service_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_contracts_service_contract_id_seq', 84, true);


--
-- Name: service_managers_service_manager_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_managers_service_manager_id_seq', 3, true);


--
-- Name: services_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_service_id_seq', 3, true);


--
-- Name: tenants_tenant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tenants_tenant_id_seq', 100, true);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (account_id);


--
-- Name: accounts accounts_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_username_key UNIQUE (username);


--
-- Name: apartments apartments_apartment_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_apartment_name_key UNIQUE (apartment_name);


--
-- Name: apartments apartments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_pkey PRIMARY KEY (building_id, apartment_id);


--
-- Name: buildings buildings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buildings
    ADD CONSTRAINT buildings_pkey PRIMARY KEY (building_id);


--
-- Name: lease_payments lease_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease_payments
    ADD CONSTRAINT lease_payments_pkey PRIMARY KEY (lease_payment_id, lease_id);


--
-- Name: lease lease_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease
    ADD CONSTRAINT lease_pkey PRIMARY KEY (lease_id);


--
-- Name: occupants occupants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.occupants
    ADD CONSTRAINT occupants_pkey PRIMARY KEY (occupant_id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);


--
-- Name: services s_name_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT s_name_unique UNIQUE (service_name);


--
-- Name: service_categories service_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_categories
    ADD CONSTRAINT service_categories_pkey PRIMARY KEY (service_category_id);


--
-- Name: service_contracts service_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_contracts
    ADD CONSTRAINT service_contracts_pkey PRIMARY KEY (service_contract_id);


--
-- Name: service_managers service_managers_account_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers
    ADD CONSTRAINT service_managers_account_id_key UNIQUE (account_id);


--
-- Name: service_managers service_managers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers
    ADD CONSTRAINT service_managers_pkey PRIMARY KEY (service_manager_id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


--
-- Name: service_managers sm_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers
    ADD CONSTRAINT sm_email_unique UNIQUE (email);


--
-- Name: service_managers sm_phone_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers
    ADD CONSTRAINT sm_phone_unique UNIQUE (phone_number);


--
-- Name: tenants tenants_account_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_account_id_key UNIQUE (account_id);


--
-- Name: tenants tenants_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_email_unique UNIQUE (email);


--
-- Name: tenants tenants_idcard_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_idcard_unique UNIQUE (id_card);


--
-- Name: tenants tenants_phone_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_phone_unique UNIQUE (phone_number);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (tenant_id);


--
-- Name: apartment_lease_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX apartment_lease_idx ON public.lease USING btree (building_id, apartment_id);


--
-- Name: service_category_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX service_category_idx ON public.service_contracts USING hash (service_category_id);


--
-- Name: service_contract_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX service_contract_idx ON public.service_contracts USING hash (service_contract_id);


--
-- Name: tenant_lease_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tenant_lease_idx ON public.lease USING hash (tenant_id);


--
-- Name: lease trigger_check_active_lease; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_check_active_lease BEFORE INSERT ON public.lease FOR EACH ROW EXECUTE FUNCTION public.check_active_lease();


--
-- Name: accounts accounts_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(role_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: apartments apartments_building_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_building_id_fkey FOREIGN KEY (building_id) REFERENCES public.buildings(building_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: lease lease_building_id_apartment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease
    ADD CONSTRAINT lease_building_id_apartment_id_fkey FOREIGN KEY (building_id, apartment_id) REFERENCES public.apartments(building_id, apartment_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: lease_payments lease_payments_lease_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease_payments
    ADD CONSTRAINT lease_payments_lease_id_fkey FOREIGN KEY (lease_id) REFERENCES public.lease(lease_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: lease lease_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lease
    ADD CONSTRAINT lease_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(tenant_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: occupants occupants_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.occupants
    ADD CONSTRAINT occupants_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(tenant_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: service_categories service_categories_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_categories
    ADD CONSTRAINT service_categories_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: service_contracts service_contracts_service_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_contracts
    ADD CONSTRAINT service_contracts_service_category_id_fkey FOREIGN KEY (service_category_id) REFERENCES public.service_categories(service_category_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: service_contracts service_contracts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_contracts
    ADD CONSTRAINT service_contracts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(tenant_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: service_managers service_managers_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers
    ADD CONSTRAINT service_managers_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(account_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: service_managers service_managers_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_managers
    ADD CONSTRAINT service_managers_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tenants tenants_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(account_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: FUNCTION available_apartment(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.available_apartment() TO admin1;


--
-- Name: PROCEDURE check_lease(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.check_lease() TO admin1;


--
-- Name: PROCEDURE confirm_payment(IN lease_payment_id_v integer, IN payment_type_v character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.confirm_payment(IN lease_payment_id_v integer, IN payment_type_v character varying) TO admin1;


--
-- Name: FUNCTION count_tenants_use_service_between_dates(_account_id integer, _from_date date, _to_date date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.count_tenants_use_service_between_dates(_account_id integer, _from_date date, _to_date date) TO manager_group;


--
-- Name: PROCEDURE delete_occupant(IN _account_id integer, IN _occupant_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.delete_occupant(IN _account_id integer, IN _occupant_id integer) TO tenant_group;


--
-- Name: FUNCTION delete_service(service_id_v integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_service(service_id_v integer) TO admin1;


--
-- Name: PROCEDURE delete_service_category(IN _account_id integer, IN _service_category_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.delete_service_category(IN _account_id integer, IN _service_category_id integer) TO manager_group;


--
-- Name: PROCEDURE delete_service_contract(IN _account_id integer, IN _service_contract_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.delete_service_contract(IN _account_id integer, IN _service_contract_id integer) TO manager_group;


--
-- Name: FUNCTION delete_tenant(tenant_id_v integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_tenant(tenant_id_v integer) TO admin1;


--
-- Name: FUNCTION get_active_service_contracts_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_active_service_contracts_by_account_id(_account_id integer) TO manager_group;


--
-- Name: TABLE apartments; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.apartments TO admin1;
GRANT SELECT ON TABLE public.apartments TO tenant_group;


--
-- Name: FUNCTION get_apartments_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_apartments_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: TABLE buildings; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.buildings TO admin1;
GRANT SELECT ON TABLE public.buildings TO tenant_group;


--
-- Name: FUNCTION get_building_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_building_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: FUNCTION get_expired_service_contracts_by_account_id_after_days(_account_id integer, _day_after integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_expired_service_contracts_by_account_id_after_days(_account_id integer, _day_after integer) TO manager_group;


--
-- Name: TABLE lease; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.lease TO admin1;
GRANT SELECT ON TABLE public.lease TO manager_group;
GRANT SELECT ON TABLE public.lease TO tenant_group;


--
-- Name: FUNCTION get_lease_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_lease_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: TABLE lease_payments; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.lease_payments TO admin1;
GRANT SELECT ON TABLE public.lease_payments TO tenant_group;


--
-- Name: FUNCTION get_lease_payments_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_lease_payments_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: TABLE occupants; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.occupants TO admin1;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.occupants TO tenant_group;


--
-- Name: FUNCTION get_occupants_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_occupants_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: TABLE services; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.services TO admin1;
GRANT SELECT ON TABLE public.services TO manager_group;


--
-- Name: FUNCTION get_service_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_service_by_account_id(_account_id integer) TO manager_group;


--
-- Name: TABLE service_categories; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.service_categories TO admin1;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.service_categories TO manager_group;


--
-- Name: FUNCTION get_service_category_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_service_category_by_account_id(_account_id integer) TO manager_group;


--
-- Name: FUNCTION get_service_contracts_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_service_contracts_by_account_id(_account_id integer) TO manager_group;


--
-- Name: FUNCTION get_service_contracts_by_account_id_and_tenant_id(_account_id integer, _tenant_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_service_contracts_by_account_id_and_tenant_id(_account_id integer, _tenant_id integer) TO manager_group;


--
-- Name: TABLE service_managers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.service_managers TO admin1;
GRANT SELECT ON TABLE public.service_managers TO manager_group;


--
-- Name: FUNCTION get_service_manager_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_service_manager_by_account_id(_account_id integer) TO manager_group;


--
-- Name: TABLE tenants; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tenants TO admin1;
GRANT SELECT ON TABLE public.tenants TO manager_group;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tenants TO tenant_group;


--
-- Name: FUNCTION get_tenants_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_tenants_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: FUNCTION get_unpaid_lease_payments_by_account_id(_account_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_unpaid_lease_payments_by_account_id(_account_id integer) TO tenant_group;


--
-- Name: PROCEDURE insert_new_resident(IN last_name character varying, IN first_name character varying, IN id_card character varying, IN email character varying, IN phone_number character varying, IN lease_start_date date, IN lease_end_date date, IN monthly_rent integer, IN apartment_id_v integer, IN building_id_v integer, IN username character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.insert_new_resident(IN last_name character varying, IN first_name character varying, IN id_card character varying, IN email character varying, IN phone_number character varying, IN lease_start_date date, IN lease_end_date date, IN monthly_rent integer, IN apartment_id_v integer, IN building_id_v integer, IN username character varying) TO admin1;


--
-- Name: PROCEDURE insert_new_service(IN last_name_v character varying, IN first_name_v character varying, IN email_v character varying, IN phone_number_v character varying, IN username_v character varying, IN service_name_v character varying, IN note_v text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.insert_new_service(IN last_name_v character varying, IN first_name_v character varying, IN email_v character varying, IN phone_number_v character varying, IN username_v character varying, IN service_name_v character varying, IN note_v text) TO admin1;


--
-- Name: PROCEDURE insert_occupants(IN _account_id integer, IN _last_name character varying, IN _first_name character varying, IN _id_card character varying, IN _phone_number character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.insert_occupants(IN _account_id integer, IN _last_name character varying, IN _first_name character varying, IN _id_card character varying, IN _phone_number character varying) TO tenant_group;


--
-- Name: PROCEDURE insert_service_category(IN _account_id integer, IN _service_id integer, IN _service_category_name character varying, IN _price integer, IN _note character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.insert_service_category(IN _account_id integer, IN _service_id integer, IN _service_category_name character varying, IN _price integer, IN _note character varying) TO manager_group;


--
-- Name: PROCEDURE insert_service_contract(IN _account_id integer, IN _tenant_id integer, IN _service_category_id integer, IN _payment_date date, IN _end_date date, IN _quantity integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.insert_service_contract(IN _account_id integer, IN _tenant_id integer, IN _service_category_id integer, IN _payment_date date, IN _end_date date, IN _quantity integer) TO manager_group;


--
-- Name: FUNCTION lease_expired_days(days_v integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.lease_expired_days(days_v integer) TO admin1;


--
-- Name: PROCEDURE refresh_service_contract(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.refresh_service_contract() TO manager_group;


--
-- Name: FUNCTION total_resident(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.total_resident() TO admin1;


--
-- Name: FUNCTION total_service(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.total_service() TO admin1;


--
-- Name: FUNCTION view_active_lease(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.view_active_lease() TO admin1;


--
-- Name: TABLE accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.accounts TO admin1;
GRANT SELECT ON TABLE public.accounts TO manager_group;


--
-- Name: SEQUENCE accounts_account_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.accounts_account_id_seq TO admin1;


--
-- Name: SEQUENCE lease_lease_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.lease_lease_id_seq TO admin1;


--
-- Name: SEQUENCE lease_payments_lease_payment_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.lease_payments_lease_payment_id_seq TO admin1;


--
-- Name: SEQUENCE occupants_occupant_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.occupants_occupant_id_seq TO tenant_group;


--
-- Name: TABLE roles; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.roles TO admin1;


--
-- Name: SEQUENCE service_categories_service_category_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.service_categories_service_category_id_seq TO manager_group;


--
-- Name: TABLE service_contracts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.service_contracts TO admin1;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.service_contracts TO manager_group;


--
-- Name: SEQUENCE service_contracts_service_contract_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.service_contracts_service_contract_id_seq TO manager_group;


--
-- Name: SEQUENCE service_managers_service_manager_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.service_managers_service_manager_id_seq TO admin1;


--
-- Name: SEQUENCE services_service_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.services_service_id_seq TO admin1;


--
-- Name: SEQUENCE tenants_tenant_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.tenants_tenant_id_seq TO admin1;


--
-- PostgreSQL database dump complete
--

