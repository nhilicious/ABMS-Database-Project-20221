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
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame1")

    def check_info():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_tenants_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def check_occupant():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_occupants_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def check_apartment():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_apartments_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def check_building():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_building_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def check_lease():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_lease_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def check_lease_payment():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_lease_payments_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def check_unpaid_lease_payments():
        cursor.execute(
            "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_unpaid_lease_payments_by_account_id(CAST(%s AS INT))) t",
            (account_id,)
        )
        result = cursor.fetchone()[0]
        show_result(result, entry_6)

    def insert_occupant(entry_1t, entry_2t, entry_3t, entry_4t):
        last_name = entry_1t.get()
        first_name = entry_2t.get()
        id_card = entry_3t.get()
        phone_number = entry_4t.get()
        try:
            cursor.execute(
                "CALL insert_occupants(CAST(%s AS INT), %s, %s, %s, %s);",
                (account_id, last_name, first_name, id_card, phone_number)
            )
            conn.commit()
            result = "Insert Occupant" + last_name + first_name + " Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_6.delete("1.0", "end")
        entry_6.insert("1.0", result)

    def delete_occupant(entry_5t):
        occupant_id = entry_5t.get()
        try:
            cursor.execute(
                "CALL delete_occupant(CAST(%s AS INT), CAST(%s AS INT));",
                (account_id, occupant_id)
            )
            conn.commit()
            result = "Delete Occupant Done!"
        except psycopg2.DatabaseError as e:
            conn.rollback()  # rollback the transaction
            result = "DatabaseError: " + str(e)
        except Exception as e:
            conn.rollback()  # rollback the transaction
            result = "Error:" + str(e)
        entry_6.delete("1.0", "end")
        entry_6.insert("1.0", result)

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)

    window = Tk()

    window.geometry("960x540")
    window.configure(bg="#FFFFFF")

    canvas = Canvas(
        window,
        bg="#FFFFFF",
        height=540,
        width=960,
        bd=0,
        highlightthickness=0,
        relief="ridge"
    )

    canvas.place(x=0, y=0)
    canvas.create_text(
        28.0,
        5.0,
        anchor="nw",
        text="Tenant: " + name,
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
        text="account id:" + str(account_id),
        fill="#000000",
        font=("Inter SemiBold", 20 * -1)
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
        command=lambda: check_occupant(),
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
        command=lambda: check_apartment(),
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
        command=lambda: check_building(),
        relief="flat"
    )
    button_4.place(
        x=28.0,
        y=293.0,
        width=162.0,
        height=45.0
    )

    button_image_5 = PhotoImage(
        file=relative_to_assets("button_5.png"))
    button_5 = Button(
        image=button_image_5,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_lease(),
        relief="flat"
    )
    button_5.place(
        x=34.0,
        y=354.0,
        width=162.0,
        height=45.0
    )

    button_image_6 = PhotoImage(
        file=relative_to_assets("button_6.png"))
    button_6 = Button(
        image=button_image_6,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_lease_payment(),
        relief="flat"
    )
    button_6.place(
        x=35.0,
        y=415.0,
        width=162.0,
        height=45.0
    )

    button_image_7 = PhotoImage(
        file=relative_to_assets("button_7.png"))
    button_7 = Button(
        image=button_image_7,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: check_unpaid_lease_payments(),
        relief="flat"
    )
    button_7.place(
        x=35.0,
        y=476.0,
        width=162.0,
        height=45.0
    )

    image_image_1 = PhotoImage(
        file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image(
        353.0,
        212.0,
        image=image_image_1
    )

    button_image_8 = PhotoImage(
        file=relative_to_assets("button_8.png"))
    button_8 = Button(
        image=button_image_8,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: insert_occupant(entry_1, entry_2, entry_3, entry_4),
        relief="flat"
    )
    button_8.place(
        x=325.0,
        y=291.0,
        width=57.0,
        height=15.0
    )

    entry_image_1 = PhotoImage(
        file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image(
        354.0,
        164.5,
        image=entry_image_1
    )
    entry_1 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_1.place(
        x=277.0,
        y=158.0,
        width=154.0,
        height=11.0
    )

    entry_image_2 = PhotoImage(
        file=relative_to_assets("entry_2.png"))
    entry_bg_2 = canvas.create_image(
        354.0,
        199.5,
        image=entry_image_2
    )
    entry_2 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_2.place(
        x=277.0,
        y=193.0,
        width=154.0,
        height=11.0
    )

    entry_image_3 = PhotoImage(
        file=relative_to_assets("entry_3.png"))
    entry_bg_3 = canvas.create_image(
        354.0,
        235.5,
        image=entry_image_3
    )
    entry_3 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_3.place(
        x=277.0,
        y=229.0,
        width=154.0,
        height=11.0
    )

    entry_image_4 = PhotoImage(
        file=relative_to_assets("entry_4.png"))
    entry_bg_4 = canvas.create_image(
        355.0,
        272.5,
        image=entry_image_4
    )
    entry_4 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_4.place(
        x=278.0,
        y=266.0,
        width=154.0,
        height=11.0
    )

    image_image_2 = PhotoImage(
        file=relative_to_assets("image_2.png"))
    image_2 = canvas.create_image(
        354.0,
        404.0,
        image=image_image_2
    )

    button_image_9 = PhotoImage(
        file=relative_to_assets("button_9.png"))
    button_9 = Button(
        image=button_image_9,
        borderwidth=0,
        highlightthickness=0,
        command=lambda: delete_occupant(entry_5),
        relief="flat"
    )
    button_9.place(
        x=325.0,
        y=428.0,
        width=57.0,
        height=15.0
    )

    entry_image_5 = PhotoImage(
        file=relative_to_assets("entry_5.png"))
    entry_bg_5 = canvas.create_image(
        355.0,
        409.5,
        image=entry_image_5
    )
    entry_5 = Entry(
        bd=0,
        bg="#E7E7E7",
        fg="#000716",
        highlightthickness=0
    )
    entry_5.place(
        x=278.0,
        y=403.0,
        width=154.0,
        height=11.0
    )

    canvas.create_rectangle(
        475.0,
        -5.0,
        480.0,
        540.0,
        fill="#000000",
        outline="")

    canvas.create_text(
        517.0,
        24.0,
        anchor="nw",
        text="JSON Result",
        fill="#000000",
        font=("Inter SemiBold", 24 * -1)
    )

    image_image_3 = PhotoImage(
        file=relative_to_assets("image_3.png"))
    image_3 = canvas.create_image(
        726.0,
        292.0,
        image=image_image_3
    )

    entry_image_6 = PhotoImage(
        file=relative_to_assets("entry_6.png"))
    entry_bg_6 = canvas.create_image(
        726.0,
        294.0,
        image=entry_image_6
    )
    entry_6 = Text(
        bd=0,
        bg="#FFFFFF",
        fg="#000716",
        highlightthickness=0
    )
    entry_6.place(
        x=531.0,
        y=89.0,
        width=390.0,
        height=408.0
    )
    window.resizable(False, False)
    window.mainloop()
