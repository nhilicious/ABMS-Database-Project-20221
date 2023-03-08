from tkinter import Tk, Canvas, Entry, Text, Button, PhotoImage
from pathlib import Path
from generalFunction import show_result
import psycopg2

conn = None
cursor = None
username = None
account_id = None
role_id = None
name = None


def start():
    OUTPUT_PATH = Path(__file__).parent
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame3")

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)

    def check_total_residents():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM total_resident2) t"
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def check_total_services():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM total_service) t"
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def check_active_leases():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM active_lease) t"
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def update_leases():
        try:
            cursor.execute(
                "CALL check_lease();"
            )
            conn.commit()
            result = "Update lease Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def check_expired_leases_after_days(entry_2t):
        days = entry_2t.get()
        try:
            cursor.execute(
                "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM lease_expired_days(CAST(%s AS INT))) t",
                (days,)
            )
            result = cursor.fetchone()[0]
            show_result(result, entry_1)
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
            entry_1.delete("1.0", "end")
            entry_1.insert("1.0", result)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
            entry_1.delete("1.0", "end")
            entry_1.insert("1.0", result)

    def confirm_lease_payment(entry_3t, entry_4t):
        lease_payment_id = entry_3t.get()
        payment_type = entry_4t.get()
        try:
            cursor.execute(
                "CALL confirm_payment(CAST(%s AS INT), %s);",
                (lease_payment_id, payment_type)
            )
            conn.commit()
            result = "Confirm lease payment " + lease_payment_id + ": Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def insert_resident(entry_5t, entry_6t, entry_7t, entry_8t, entry_9t, entry_10t,
                        entry_11t, entry_12t, entry_13t, entry_14t, entry_15t):
        last_name = entry_5t.get()
        first_name = entry_6t.get()
        id_card = entry_7t.get()
        email = entry_8t.get()
        phone = entry_9t.get()
        lease_start_date = entry_10t.get()
        lease_end_date = entry_11t.get()
        monthly_rent = entry_12t.get()
        apartment_id = entry_13t.get()
        building_id = entry_14t.get()
        username_t = entry_15t.get()
        try:
            cursor.execute(
                "CALL insert_new_resident(%s, %s, %s, %s, %s, CAST(%s AS DATE), CAST(%s AS DATE), CAST(%s AS INT), "
                "CAST(%s AS INT), CAST(%s AS INT), %s);",
                (last_name, first_name, id_card, email, phone, lease_start_date, lease_end_date, monthly_rent,
                 apartment_id, building_id, username_t)
            )
            conn.commit()
            result = "Insert Tenant " + last_name + " " + first_name + " Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def insert_service(entry_16t, entry_17t, entry_18t, entry_19t, entry_20t, entry_21t, entry_22t):
        last_name = entry_16t.get()
        first_name = entry_17t.get()
        email = entry_18t.get()
        phone = entry_19t.get()
        username_t = entry_20t.get()
        service_name = entry_21t.get()
        note = entry_22t.get()
        try:
            cursor.execute(
                "CALL insert_new_service(%s, %s, %s, %s, %s, %s, CAST(%s AS TEXT));",
                (last_name, first_name, email, phone, username_t, service_name, note)
            )
            conn.commit()
            result = "Insert New Service " + service_name + " Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def delete_resident(entry_23t):
        tenant_id = entry_23t.get()
        try:
            cursor.execute(
                "SELECT * FROM delete_tenant(CAST(%s AS INT)) t",
                (tenant_id,)
            )
            conn.commit()
            result = "Delete Tenant With ID " + str(tenant_id) + " Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def delete_service(entry_24t):
        service_id = entry_24t.get()
        try:
            cursor.execute(
                "SELECT * FROM delete_service(CAST(%s AS INT)) t",
                (service_id,)
            )
            conn.commit()
            result = "Delete Service With ID " + str(service_id) + " Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def check_available_apartment():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM available_apartment()) t"
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    window = Tk()

    window.geometry("1000x540")
    window.configure(bg="#FFFFFF")

    canvas = Canvas(
        window,
        bg="#FFFFFF",
        height=540,
        width=1000,
        bd=0,
        highlightthickness=0,
        relief="ridge"
    )

    canvas.place(x=0, y=0)
    canvas.create_text(
        31.0,
        5.0,
        anchor="nw",
        text="Admin: " + name,
        fill="#000000",
        font=("Inter SemiBold", 24 * -1)
    )

    canvas.create_text(
        28.0,
        39.0,
        anchor="nw",
        text="username: " + username,
        fill="#000000",
        font=("Inter SemiBold", 20 * -1)
    )

    canvas.create_text(
        26.0,
        69.0,
        anchor="nw",
        text="account id: " + str(account_id),
        fill="#000000",
        font=("Inter SemiBold", 20 * -1)
    )

    canvas.create_rectangle(
        587.0,
        -5.0,
        592.0,
        540.0,
        fill="#000000",
        outline="")

    canvas.create_text(
        604.0,
        24.0,
        anchor="nw",
        text="JSON Result",
        fill="#000000",
        font=("Inter SemiBold", 24 * -1)
    )

    image_image_1 = PhotoImage(
        file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image(
        792.0,
        292.0,
        image=image_image_1
    )

    entry_image_1 = PhotoImage(
        file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image(
        795.0,
        294.0,
        image=entry_image_1
    )
    entry_1 = Text(
        bd=0,
        bg="#FFFFFF",
        fg="#000716",
        highlightthickness=0
    )
    entry_1.place(
        x=621.0,
        y=89.0,
        width=348.0,
        height=408.0
    )

    button_image_1 = PhotoImage(
        file=relative_to_assets("button_1.png"))
    button_1 = Button(
        image=button_image_1,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_total_residents(),
        relief="flat"
    )
    button_1.place(
        x=28.0,
        y=110.0,
        width=162.0,
        height=45.0
    )

    button_image_2 = PhotoImage(
        file=relative_to_assets("button_2.png"))
    button_2 = Button(
        image=button_image_2,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_total_services(),
        relief="flat"
    )
    button_2.place(
        x=28.0,
        y=171.0,
        width=162.0,
        height=45.0
    )

    button_image_3 = PhotoImage(
        file=relative_to_assets("button_3.png"))
    button_3 = Button(
        image=button_image_3,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_active_leases(),
        relief="flat"
    )
    button_3.place(
        x=28.0,
        y=232.0,
        width=162.0,
        height=45.0
    )

    button_image_4 = PhotoImage(
        file=relative_to_assets("button_4.png"))
    button_4 = Button(
        image=button_image_4,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: update_leases(),
        relief="flat"
    )
    button_4.place(
        x=28.0,
        y=293.0,
        width=162.0,
        height=45.0
    )

    image_image_2 = PhotoImage(
        file=relative_to_assets("image_2.png"))
    image_2 = canvas.create_image(
        58.0,
        450.0,
        image=image_image_2
    )

    button_image_5 = PhotoImage(
        file=relative_to_assets("button_5.png"))
    button_5 = Button(
        image=button_image_5,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_expired_leases_after_days(entry_2),
        relief="flat"
    )
    button_5.place(
        x=30.0,
        y=474.0,
        width=57.0,
        height=15.0
    )

    entry_image_2 = PhotoImage(
        file=relative_to_assets("entry_2.png"))
    entry_bg_2 = canvas.create_image(
        59.0,
        455.5,
        image=entry_image_2
    )
    entry_2 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_2.place(
        x=25.0,
        y=449.0,
        width=68.0,
        height=11.0
    )

    image_image_3 = PhotoImage(
        file=relative_to_assets("image_3.png"))
    image_3 = canvas.create_image(
        157.0,
        465.0,
        image=image_image_3
    )

    button_image_6 = PhotoImage(
        file=relative_to_assets("button_6.png"))
    button_6 = Button(
        image=button_image_6,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: confirm_lease_payment(entry_3, entry_4),
        relief="flat"
    )
    button_6.place(
        x=129.0,
        y=508.0,
        width=57.0,
        height=15.0
    )

    entry_image_3 = PhotoImage(
        file=relative_to_assets("entry_3.png"))
    entry_bg_3 = canvas.create_image(
        158.0,
        455.5,
        image=entry_image_3
    )
    entry_3 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_3.place(
        x=124.0,
        y=449.0,
        width=68.0,
        height=11.0
    )

    entry_image_4 = PhotoImage(
        file=relative_to_assets("entry_4.png"))
    entry_bg_4 = canvas.create_image(
        158.0,
        489.5,
        image=entry_image_4
    )
    entry_4 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_4.place(
        x=124.0,
        y=483.0,
        width=68.0,
        height=11.0
    )

    image_image_4 = PhotoImage(
        file=relative_to_assets("image_4.png"))
    image_4 = canvas.create_image(
        300.0,
        287.0,
        image=image_image_4
    )

    button_image_7 = PhotoImage(
        file=relative_to_assets("button_7.png"))
    button_7 = Button(
        image=button_image_7,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: insert_resident(entry_5, entry_6, entry_7, entry_8, entry_9, entry_10,
                                        entry_11, entry_12, entry_13, entry_14, entry_15),
        relief="flat"
    )
    button_7.place(
        x=272.0,
        y=444.0,
        width=57.0,
        height=15.0
    )

    entry_image_5 = PhotoImage(
        file=relative_to_assets("entry_5.png"))
    entry_bg_5 = canvas.create_image(
        301.0,
        164.5,
        image=entry_image_5
    )
    entry_5 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_5.place(
        x=224.0,
        y=158.0,
        width=154.0,
        height=11.0
    )

    entry_image_6 = PhotoImage(
        file=relative_to_assets("entry_6.png"))
    entry_bg_6 = canvas.create_image(
        301.0,
        199.5,
        image=entry_image_6
    )
    entry_6 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_6.place(
        x=224.0,
        y=193.0,
        width=154.0,
        height=11.0
    )

    entry_image_7 = PhotoImage(
        file=relative_to_assets("entry_7.png"))
    entry_bg_7 = canvas.create_image(
        301.0,
        235.5,
        image=entry_image_7
    )
    entry_7 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_7.place(
        x=224.0,
        y=229.0,
        width=154.0,
        height=11.0
    )

    entry_image_8 = PhotoImage(
        file=relative_to_assets("entry_8.png"))
    entry_bg_8 = canvas.create_image(
        302.0,
        272.5,
        image=entry_image_8
    )
    entry_8 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_8.place(
        x=225.0,
        y=266.0,
        width=154.0,
        height=11.0
    )

    entry_image_9 = PhotoImage(
        file=relative_to_assets("entry_9.png"))
    entry_bg_9 = canvas.create_image(
        302.0,
        310.5,
        image=entry_image_9
    )
    entry_9 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_9.place(
        x=225.0,
        y=304.0,
        width=154.0,
        height=11.0
    )

    entry_image_10 = PhotoImage(
        file=relative_to_assets("entry_10.png"))
    entry_bg_10 = canvas.create_image(
        257.5,
        348.5,
        image=entry_image_10
    )
    entry_10 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_10.place(
        x=222.0,
        y=342.0,
        width=71.0,
        height=11.0
    )

    entry_image_11 = PhotoImage(
        file=relative_to_assets("entry_11.png"))
    entry_bg_11 = canvas.create_image(
        343.0,
        348.5,
        image=entry_image_11
    )
    entry_11 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_11.place(
        x=308.0,
        y=342.0,
        width=70.0,
        height=11.0
    )

    entry_image_12 = PhotoImage(
        file=relative_to_assets("entry_12.png"))
    entry_bg_12 = canvas.create_image(
        257.5,
        386.5,
        image=entry_image_12
    )
    entry_12 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_12.place(
        x=222.0,
        y=380.0,
        width=71.0,
        height=11.0
    )

    entry_image_13 = PhotoImage(
        file=relative_to_assets("entry_13.png"))
    entry_bg_13 = canvas.create_image(
        342.0,
        386.5,
        image=entry_image_13
    )
    entry_13 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_13.place(
        x=307.0,
        y=380.0,
        width=70.0,
        height=11.0
    )

    entry_image_14 = PhotoImage(
        file=relative_to_assets("entry_14.png"))
    entry_bg_14 = canvas.create_image(
        257.0,
        424.5,
        image=entry_image_14
    )
    entry_14 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_14.place(
        x=222.0,
        y=418.0,
        width=70.0,
        height=11.0
    )

    entry_image_15 = PhotoImage(
        file=relative_to_assets("entry_15.png"))
    entry_bg_15 = canvas.create_image(
        342.0,
        424.5,
        image=entry_image_15
    )
    entry_15 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_15.place(
        x=307.0,
        y=418.0,
        width=70.0,
        height=11.0
    )

    image_image_5 = PhotoImage(
        file=relative_to_assets("image_5.png"))
    image_5 = canvas.create_image(
        492.0,
        251.0,
        image=image_image_5
    )

    button_image_8 = PhotoImage(
        file=relative_to_assets("button_8.png"))
    button_8 = Button(
        image=button_image_8,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: insert_service(entry_16, entry_17, entry_18, entry_19, entry_20, entry_21, entry_22),
        relief="flat"
    )
    button_8.place(
        x=465.0,
        y=367.0,
        width=57.0,
        height=15.0
    )

    entry_image_16 = PhotoImage(
        file=relative_to_assets("entry_16.png"))
    entry_bg_16 = canvas.create_image(
        493.0,
        164.5,
        image=entry_image_16
    )
    entry_16 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_16.place(
        x=416.0,
        y=158.0,
        width=154.0,
        height=11.0
    )

    entry_image_17 = PhotoImage(
        file=relative_to_assets("entry_17.png"))
    entry_bg_17 = canvas.create_image(
        493.0,
        199.5,
        image=entry_image_17
    )
    entry_17 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_17.place(
        x=416.0,
        y=193.0,
        width=154.0,
        height=11.0
    )

    entry_image_18 = PhotoImage(
        file=relative_to_assets("entry_18.png"))
    entry_bg_18 = canvas.create_image(
        493.0,
        235.5,
        image=entry_image_18
    )
    entry_18 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_18.place(
        x=416.0,
        y=229.0,
        width=154.0,
        height=11.0
    )

    entry_image_19 = PhotoImage(
        file=relative_to_assets("entry_19.png"))
    entry_bg_19 = canvas.create_image(
        494.0,
        272.5,
        image=entry_image_19
    )
    entry_19 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_19.place(
        x=417.0,
        y=266.0,
        width=154.0,
        height=11.0
    )

    entry_image_20 = PhotoImage(
        file=relative_to_assets("entry_20.png"))
    entry_bg_20 = canvas.create_image(
        450.5,
        310.5,
        image=entry_image_20
    )
    entry_20 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_20.place(
        x=415.0,
        y=304.0,
        width=71.0,
        height=11.0
    )

    entry_image_21 = PhotoImage(
        file=relative_to_assets("entry_21.png"))
    entry_bg_21 = canvas.create_image(
        536.0,
        310.5,
        image=entry_image_21
    )
    entry_21 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_21.place(
        x=501.0,
        y=304.0,
        width=70.0,
        height=11.0
    )

    entry_image_22 = PhotoImage(
        file=relative_to_assets("entry_22.png"))
    entry_bg_22 = canvas.create_image(
        495.0,
        348.5,
        image=entry_image_22
    )
    entry_22 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_22.place(
        x=418.0,
        y=342.0,
        width=154.0,
        height=11.0
    )

    image_image_6 = PhotoImage(
        file=relative_to_assets("image_6.png"))
    image_6 = canvas.create_image(
        445.0,
        461.0,
        image=image_image_6
    )

    button_image_9 = PhotoImage(
        file=relative_to_assets("button_9.png"))
    button_9 = Button(
        image=button_image_9,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: delete_resident(entry_23),
        relief="flat"
    )
    button_9.place(
        x=418.0,
        y=485.0,
        width=57.0,
        height=15.0
    )

    entry_image_23 = PhotoImage(
        file=relative_to_assets("entry_23.png"))
    entry_bg_23 = canvas.create_image(
        446.5,
        466.5,
        image=entry_image_23
    )
    entry_23 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_23.place(
        x=417.0,
        y=460.0,
        width=59.0,
        height=11.0
    )

    image_image_7 = PhotoImage(
        file=relative_to_assets("image_7.png"))
    image_7 = canvas.create_image(
        538.0,
        461.0,
        image=image_image_7
    )

    button_image_10 = PhotoImage(
        file=relative_to_assets("button_10.png"))
    button_10 = Button(
        image=button_image_10,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: delete_service(entry_24),
        relief="flat"
    )
    button_10.place(
        x=511.0,
        y=485.0,
        width=57.0,
        height=15.0
    )

    entry_image_24 = PhotoImage(
        file=relative_to_assets("entry_24.png"))
    entry_bg_24 = canvas.create_image(
        539.5,
        466.5,
        image=entry_image_24
    )
    entry_24 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_24.place(
        x=510.0,
        y=460.0,
        width=59.0,
        height=11.0
    )

    button_image_11 = PhotoImage(
        file=relative_to_assets("button_11.png"))
    button_11 = Button(
        image=button_image_11,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_available_apartment(),
        relief="flat"
    )
    button_11.place(
        x=25.0,
        y=352.0,
        width=162.0,
        height=45.0
    )

    window.resizable(False, False)
    window.mainloop()
