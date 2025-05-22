from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, date


db = SQLAlchemy()

class Users(db.Model):
    user_id = db.Column(db.String, primary_key=True)
    user_name = db.Column(db.String, nullable=False)
    password = db.Column(db.String, nullable=False)
    email = db.Column(db.String, nullable=False)
    ph_no = db.Column(db.String, nullable=False)
    last_loged = db.Column(db.DateTime, default = datetime.strftime(date(2018,1,23), "%d-%m-%Y"))
    gender = db.Column(db.String, nullable=False)
    dob = db.Column(db.DateTime, default = datetime.strftime(date(1990,8,4), "%d-%m-%Y"), nullable=False)

class Medicines(db.Model):
    med_id = db.Column(db.String, primary_key=True)
    med_name = db.Column(db.String, nullable=False)
    recommended_dosage = db.Column(db.String, nullable=False)
    side_effects = db.Column(db.String, nullable=False)

class Prescriptions(db.Model):
    pres_id = db.Column(db.String, primary_key=True)
    med_id = db.Column(db.String, nullable=False)
    user_id = db.Column(db.String, nullable=False)
    frequency = db.Column(db.Integer, nullable=False)
    expiry_date = db.Column(db.String, nullable=False)