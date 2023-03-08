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
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame2")

    def check_info():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_service_manager_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def check_service():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_service_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def check_service_categories():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_service_category_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def check_service_contracts():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_service_contracts_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def check_active_service_contracts():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_active_service_contracts_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_1)

    def refresh_contracts():
        try:
            cursor.execute(
                "CALL refresh_service_contract();",
            )
            conn.commit()
            result = "Refresh Data Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def check_contract_by_tenant_id(entry_2t):
        tenant_id = entry_2t.get()
        try:
            cursor.execute(
                "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_service_contracts_by_account_id_and_tenant_id(CAST(%s AS INT), CAST(%s AS INT))) t",
                (account_id, tenant_id)
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

    def check_expired_contracts_after_days(entry_3t):
        days = entry_3t.get()
        try:
            cursor.execute(
                "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_expired_service_contracts_by_account_id_after_days(CAST(%s AS INT), CAST(%s AS INT))) t",
                (account_id, days)
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

    def insert_service_contract(entry_4t, entry_5t, entry_6t, entry_8t, entry_9t):
        tenant_id = entry_4t.get()
        category_id = entry_5t.get()
        quantity = entry_6t.get()
        from_date = entry_8t.get()
        to_date = entry_9t.get()
        try:
            cursor.execute(
                "CALL insert_service_contract(CAST(%s AS INT), CAST(%s AS INT), CAST(%s AS INT), CAST(%s AS DATE), "
                "CAST(%s AS DATE), CAST(%s AS INT));",
                (account_id, tenant_id, category_id, from_date, to_date, quantity)
            )
            conn.commit()
            result = "Insert Service Contract With Category ID " + str(category_id) + " For Tenant ID" \
                     + str(tenant_id) + " Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def insert_service_category(entry_10t, entry_11t, entry_12t, entry_13t):
        service_id = entry_10t.get()
        category_name = entry_11t.get()
        price = entry_12t.get()
        note = entry_13t.get()
        try:
            cursor.execute(
                "CALL insert_service_category(CAST(%s AS INT), CAST(%s AS INT), %s, CAST(%s AS INT), %s);",
                (account_id, service_id, category_name, price, note)
            )
            conn.commit()
            result = "Insert " + category_name + " Service Category Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def delete_service_contract(entry_14t):
        service_contract_id = entry_14t.get()
        try:
            cursor.execute(
                "CALL delete_service_contract(CAST(%s AS INT), CAST(%s AS INT));",
                (account_id, service_contract_id)
            )
            conn.commit()
            result = "Delete Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def delete_service_category(entry_15t):
        service_category_id = entry_15t.get()
        try:
            cursor.execute(
                "CALL delete_service_category(CAST(%s AS INT), CAST(%s AS INT));",
                (account_id, service_category_id)
            )
            conn.commit()
            result = "Delete Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_1.delete("1.0", "end")
        entry_1.insert("1.0", result)

    def count_tenants_used_service_between_days(entry_16t, entry_17t):
        start_date = entry_16t.get()
        end_date = entry_17t.get()
        try:
            cursor.execute(
                "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM count_tenants_use_service_between_dates(CAST(%s AS INT), CAST(%s AS DATE), CAST(%s AS DATE))) t",
                (account_id, start_date, end_date)
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

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)

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
    canvas.create_rectangle(
        545.0,
        -5.0,
        550.0,
        540.0,
        fill="#000000",
        outline="")

    canvas.create_text(
        28.0,
        5.0,
        anchor="nw",
        text="Manager: " + name,
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

    canvas.create_text(
        569.0,
        24.0,
        anchor="nw",
        text="JSON Result",
        fill="#000000",
        font=("Inter SemiBold", 24 * -1)
    )

    image_image_1 = PhotoImage(
        file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image(
        778.0,
        292.0,
        image=image_image_1
    )

    entry_image_1 = PhotoImage(
        file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image(
        778.0,
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
        x=583.0,
        y=89.0,
        width=390.0,
        height=408.0
    )

    button_image_1 = PhotoImage(
        file=relative_to_assets("button_1.png"))
    button_1 = Button(
        image=button_image_1,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_info(),
        relief="flat"
    )
    button_1.place(
        x=23.0,
        y=99.0,
        width=162.0,
        height=45.0
    )

    button_image_2 = PhotoImage(
        file=relative_to_assets("button_2.png"))
    button_2 = Button(
        image=button_image_2,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_service(),
        relief="flat"
    )
    button_2.place(
        x=202.0,
        y=99.0,
        width=162.0,
        height=45.0
    )

    button_image_3 = PhotoImage(
        file=relative_to_assets("button_3.png"))
    button_3 = Button(
        image=button_image_3,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_service_categories(),
        relief="flat"
    )
    button_3.place(
        x=374.0,
        y=99.0,
        width=162.0,
        height=45.0
    )

    button_image_4 = PhotoImage(
        file=relative_to_assets("button_4.png"))
    button_4 = Button(
        image=button_image_4,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_service_contracts(),
        relief="flat"
    )
    button_4.place(
        x=22.0,
        y=160.0,
        width=162.0,
        height=45.0
    )

    button_image_5 = PhotoImage(
        file=relative_to_assets("button_5.png"))
    button_5 = Button(
        image=button_image_5,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_active_service_contracts(),
        relief="flat"
    )
    button_5.place(
        x=202.0,
        y=160.0,
        width=162.0,
        height=45.0
    )

    button_image_6 = PhotoImage(
        file=relative_to_assets("button_6.png"))
    button_6 = Button(
        image=button_image_6,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: refresh_contracts(),
        relief="flat"
    )
    button_6.place(
        x=376.0,
        y=160.0,
        width=162.0,
        height=45.0
    )

    image_image_2 = PhotoImage(
        file=relative_to_assets("image_2.png"))
    image_2 = canvas.create_image(
        103.0,
        266.0,
        image=image_image_2
    )

    button_image_7 = PhotoImage(
        file=relative_to_assets("button_7.png"))
    button_7 = Button(
        image=button_image_7,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_contract_by_tenant_id(entry_2),
        relief="flat"
    )
    button_7.place(
        x=74.0,
        y=292.0,
        width=57.0,
        height=15.0
    )

    entry_image_2 = PhotoImage(
        file=relative_to_assets("entry_2.png"))
    entry_bg_2 = canvas.create_image(
        103.0,
        275.0,
        image=entry_image_2
    )
    entry_2 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_2.place(
        x=40.0,
        y=268.0,
        width=126.0,
        height=12.0
    )

    image_image_3 = PhotoImage(
        file=relative_to_assets("image_3.png"))
    image_3 = canvas.create_image(
        287.0,
        267.0,
        image=image_image_3
    )

    button_image_8 = PhotoImage(
        file=relative_to_assets("button_8.png"))
    button_8 = Button(
        image=button_image_8,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_expired_contracts_after_days(entry_3),
        relief="flat"
    )
    button_8.place(
        x=258.0,
        y=293.0,
        width=57.0,
        height=15.0
    )

    entry_image_3 = PhotoImage(
        file=relative_to_assets("entry_3.png"))
    entry_bg_3 = canvas.create_image(
        287.0,
        276.0,
        image=entry_image_3
    )
    entry_3 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_3.place(
        x=224.0,
        y=269.0,
        width=126.0,
        height=12.0
    )

    image_image_4 = PhotoImage(
        file=relative_to_assets("image_4.png"))
    image_4 = canvas.create_image(
        107.0,
        380.0,
        image=image_image_4
    )

    button_image_9 = PhotoImage(
        file=relative_to_assets("button_9.png"))
    button_9 = Button(
        image=button_image_9,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: insert_service_contract(entry_4, entry_5, entry_6, entry_8, entry_9),
        relief="flat"
    )
    button_9.place(
        x=155.0,
        y=402.0,
        width=44.0,
        height=15.0
    )

    entry_image_4 = PhotoImage(
        file=relative_to_assets("entry_4.png"))
    entry_bg_4 = canvas.create_image(
        36.0,
        379.5,
        image=entry_image_4
    )
    entry_4 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_4.place(
        x=19.0,
        y=373.0,
        width=34.0,
        height=11.0
    )

    entry_image_5 = PhotoImage(
        file=relative_to_assets("entry_5.png"))
    entry_bg_5 = canvas.create_image(
        83.0,
        379.5,
        image=entry_image_5
    )
    entry_5 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_5.place(
        x=66.0,
        y=373.0,
        width=34.0,
        height=11.0
    )

    entry_image_6 = PhotoImage(
        file=relative_to_assets("entry_6.png"))
    entry_bg_6 = canvas.create_image(
        130.0,
        379.5,
        image=entry_image_6
    )
    entry_6 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_6.place(
        x=113.0,
        y=373.0,
        width=34.0,
        height=11.0
    )

    entry_image_8 = PhotoImage(
        file=relative_to_assets("entry_8.png"))
    entry_bg_8 = canvas.create_image(
        45.0,
        413.5,
        image=entry_image_8
    )
    entry_8 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_8.place(
        x=19.0,
        y=407.0,
        width=52.0,
        height=11.0
    )

    entry_image_9 = PhotoImage(
        file=relative_to_assets("entry_9.png"))
    entry_bg_9 = canvas.create_image(
        119.0,
        413.5,
        image=entry_image_9
    )
    entry_9 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_9.place(
        x=93.0,
        y=407.0,
        width=52.0,
        height=11.0
    )

    image_image_5 = PhotoImage(
        file=relative_to_assets("image_5.png"))
    image_5 = canvas.create_image(
        106.0,
        486.0,
        image=image_image_5
    )

    button_image_10 = PhotoImage(
        file=relative_to_assets("button_10.png"))
    button_10 = Button(
        image=button_image_10,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: insert_service_category(entry_10, entry_11, entry_12, entry_13),
        relief="flat"
    )
    button_10.place(
        x=83.0,
        y=510.0,
        width=44.0,
        height=15.0
    )

    entry_image_10 = PhotoImage(
        file=relative_to_assets("entry_10.png"))
    entry_bg_10 = canvas.create_image(
        35.0,
        493.5,
        image=entry_image_10
    )
    entry_10 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_10.place(
        x=18.0,
        y=487.0,
        width=34.0,
        height=11.0
    )

    entry_image_11 = PhotoImage(
        file=relative_to_assets("entry_11.png"))
    entry_bg_11 = canvas.create_image(
        82.0,
        493.5,
        image=entry_image_11
    )
    entry_11 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_11.place(
        x=65.0,
        y=487.0,
        width=34.0,
        height=11.0
    )

    entry_image_12 = PhotoImage(
        file=relative_to_assets("entry_12.png"))
    entry_bg_12 = canvas.create_image(
        129.0,
        493.5,
        image=entry_image_12
    )
    entry_12 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_12.place(
        x=112.0,
        y=487.0,
        width=34.0,
        height=11.0
    )

    entry_image_13 = PhotoImage(
        file=relative_to_assets("entry_13.png"))
    entry_bg_13 = canvas.create_image(
        176.0,
        493.5,
        image=entry_image_13
    )
    entry_13 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_13.place(
        x=159.0,
        y=487.0,
        width=34.0,
        height=11.0
    )

    image_image_6 = PhotoImage(
        file=relative_to_assets("image_6.png"))
    image_6 = canvas.create_image(
        288.0,
        379.0,
        image=image_image_6
    )

    button_image_11 = PhotoImage(
        file=relative_to_assets("button_11.png"))
    button_11 = Button(
        image=button_image_11,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: delete_service_contract(entry_14),
        relief="flat"
    )
    button_11.place(
        x=259.0,
        y=405.0,
        width=57.0,
        height=15.0
    )

    entry_image_14 = PhotoImage(
        file=relative_to_assets("entry_14.png"))
    entry_bg_14 = canvas.create_image(
        288.0,
        388.0,
        image=entry_image_14
    )
    entry_14 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_14.place(
        x=225.0,
        y=381.0,
        width=126.0,
        height=12.0
    )

    image_image_7 = PhotoImage(
        file=relative_to_assets("image_7.png"))
    image_7 = canvas.create_image(
        288.0,
        486.0,
        image=image_image_7
    )

    button_image_12 = PhotoImage(
        file=relative_to_assets("button_12.png"))
    button_12 = Button(
        image=button_image_12,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: delete_service_category(entry_15),
        relief="flat"
    )
    button_12.place(
        x=259.0,
        y=512.0,
        width=57.0,
        height=15.0
    )

    entry_image_15 = PhotoImage(
        file=relative_to_assets("entry_15.png"))
    entry_bg_15 = canvas.create_image(
        288.0,
        495.0,
        image=entry_image_15
    )
    entry_15 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_15.place(
        x=225.0,
        y=488.0,
        width=126.0,
        height=12.0
    )

    image_image_8 = PhotoImage(
        file=relative_to_assets("image_8.png"))
    image_8 = canvas.create_image(
        456.0,
        298.0,
        image=image_image_8
    )

    button_image_13 = PhotoImage(
        file=relative_to_assets("button_13.png"))
    button_13 = Button(
        image=button_image_13,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: count_tenants_used_service_between_days(entry_16, entry_17),
        relief="flat"
    )
    button_13.place(
        x=428.0,
        y=354.0,
        width=57.0,
        height=15.0
    )

    entry_image_16 = PhotoImage(
        file=relative_to_assets("entry_16.png"))
    entry_bg_16 = canvas.create_image(
        456.0,
        288.0,
        image=entry_image_16
    )
    entry_16 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_16.place(
        x=393.0,
        y=281.0,
        width=126.0,
        height=12.0
    )

    entry_image_17 = PhotoImage(
        file=relative_to_assets("entry_17.png"))
    entry_bg_17 = canvas.create_image(
        456.0,
        329.0,
        image=entry_image_17
    )
    entry_17 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_17.place(
        x=393.0,
        y=322.0,
        width=126.0,
        height=12.0
    )
    window.resizable(False, False)
    window.mainloop()
