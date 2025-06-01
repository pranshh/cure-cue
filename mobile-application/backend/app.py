# Flask & Web Framework
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename
# Database & ORM
from sqlalchemy import desc
from models import *
# AI/ML Components
from paddleocr import PaddleOCR
from ultralytics import YOLO
import google.generativeai as genai
# Image Processing
import cv2
import numpy as np
from PIL import Image
# Utilities
from datetime import datetime
import pytz
import re
import os
import json
import warnings
import logging
from time import sleep
# Fuzzy Matching
from rapidfuzz import process, fuzz
# Type Hints
from typing import Dict, Any, List
import requests

warnings.filterwarnings('ignore')
logging.basicConfig(level=logging.INFO)
logging.getLogger('paddleocr').setLevel(logging.ERROR)
logging.getLogger('paddle').setLevel(logging.ERROR)
warnings.filterwarnings('ignore', category=UserWarning, module='paddle')
os.environ['PADDLE_DISABLE_STARTUP_WARNINGS'] = '1'


# ocr = PaddleOCR(
#     use_angle_cls=True, 
#     lang='en',
#     det_db_thresh=0.3,  # Lower threshold for better detection
#     det_db_box_thresh=0.3,
#     # show_log=False,
#     # use_gpu=False,
# )

model = YOLO('expiry_date_reader_model.pt')
ocr = PaddleOCR(use_angle_cls=True, lang='en')

genai.configure(api_key='AIzaSyDChfe8INK6TpAJgFQ8gVKvSvf1Pgfiu6k')
gemini_model = genai.GenerativeModel('gemini-2.0-flash')

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///prescription.sqlite3'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = "3T9rFtQxZ1jA77sKJiy_mT6YvFP_W0C6eM67oNOxO0Y"

db.init_app(app)
CORS(app)


# Routing Functions
@app.route("/")
def index():
    return "Hello World!"

@app.route("/login", methods=["POST"])
def login():
    form = request.get_json()
    fetchUser = Users.query.filter_by(
        user_name=form["username"], password=form["password"]).first()
    if fetchUser:
        fetchUser.last_loged = datetime.now(pytz.utc)
        db.session.commit()

        return {
            "user_id": fetchUser.user_id,
            "user_name": fetchUser.user_name,
            "email": fetchUser.email,
            "ph_no": fetchUser.ph_no,
            "gender": fetchUser.gender,
            "dob": fetchUser.dob,
            "last_loged": fetchUser.last_loged,
            "success": True
        }, 200
    else:
        return {
            "success": False,
            "message": "Invalid credentials"
        }, 401

@app.route("/add-user", methods=["POST"])
def register():
    form = request.get_json()
    fetchUser = Users.query.filter_by(email=form["email"]).first()
    if fetchUser == None:
        fetchUsers = Users.query.order_by(desc(Users.user_id)).first()
        next_id = nextID(fetchUsers.user_id) if fetchUsers else "USRA0001"
        now = datetime.now()

        dob_str = form["dob"]
        try:
            dob = datetime.fromisoformat(dob_str)
        except ValueError:
            # fallback if milliseconds are present (Python <3.11)
            dob = datetime.strptime(dob_str.split('.')[0], "%Y-%m-%d %H:%M:%S")
        try:
            addUser = Users(
                user_id=next_id,
                user_name=form["name"],
                password=form["password"],
                email=form["email"],
                ph_no=form["phone"],
                last_loged=now,
                gender=form["gender"],
                dob=dob,
            )
            db.session.add(addUser)
            db.session.commit()
            return "Successfully Added", 200
        except Exception as e:
            print(e)
            return "Failed to add user", 500
    return "User already exists", 400

@app.route("/get-user-data", methods=["POST"])
def getUserData():
    form = request.get_json()
    fetchUser = Users.query.filter_by(
        user_name=form["username"], password=form["password"]).first()
    fetchPrescriptions = Prescriptions.query.filter_by(
        user_id=fetchUser.user_id).all()
    print(len(fetchPrescriptions))
    medicine_ids = [p.med_id for p in fetchPrescriptions]
    fetchMedicines = Medicines.query.filter(
        Medicines.med_id.in_(medicine_ids)).all()
    if fetchUser:
        return {
            "user_id": fetchUser.user_id,
            "user_name": fetchUser.user_name,
            "email": fetchUser.email,
            "phone": fetchUser.ph_no,
            "gender": fetchUser.gender,
            "dob": fetchUser.dob.strftime("%A, %d %B %Y"),
            "last_loged": fetchUser.last_loged.strftime("%A, %d %B %Y"),
            "prescriptions": sorted([
                {
                "pres_id": p.pres_id,
                "med_id": p.med_id,
                "medicine_name": m.med_name,
                "recommended_dosage": m.recommended_dosage,
                "side_effects": m.side_effects,
                "frequency": p.frequency,
                "expiry_date": datetime.strptime(p.expiry_date, "%Y-%m-%d %H:%M:%S").strftime("%d-%m-%Y"),
                "_expiry_datetime": datetime.strptime(p.expiry_date, "%Y-%m-%d %H:%M:%S")
            } for p, m in zip(fetchPrescriptions, fetchMedicines)
            ],
        key=lambda x: x["_expiry_datetime"], reverse=True
    ),
        }, 200
    else:
        return {
            "success": False,
            "message": "Server Error"
        }, 500

@app.route("/get-medicine", methods=["GET"])
def getMedicine():
    med_name = request.args.get("med_name", "")
    fetchMed = Medicines.query.filter(Medicines.med_name.ilike(f"%{med_name}%")).first()
    response = {
        "med_id": fetchMed.med_id if fetchMed else None,
        "med_name": fetchMed.med_name if fetchMed else None,
        "recommended_dosage": fetchMed.recommended_dosage if fetchMed else None,
        "side_effects": fetchMed.side_effects if fetchMed else None
    }
    return response, 200 if fetchMed else 404

@app.route("/add-medicine", methods=["POST"])
def addMedicine():
    form = request.get_json()
    fetchMed = Medicines.query.filter_by(med_name=form["med_name"]).first()
    if fetchMed == None:
        fetchMed = Medicines.query.order_by(desc(Medicines.med_id)).first()
        next_id = nextID(fetchMed.med_id) if fetchMed else "MEDA0001"
        addMed = Medicines(
            med_id=next_id,
            med_name=form["med_name"],
            recommended_dosage=form["recommended_dosage"],
            side_effects=form["side_effects"]
        )
        db.session.add(addMed)
        db.session.commit()
        return "Successfully Added", 200
    return "Medicine already exists", 400

@app.route("/add-prescription", methods=["POST"])
def addPrescription():
    form = request.get_json() 
    fetchUser = Users.query.filter_by(user_id=form["user_id"]).first()
    fetchMed = Medicines.query.filter_by(med_name=form["med_name"]).first()
    lastID = Prescriptions.query.order_by(Prescriptions.pres_id.desc()).first()
    next_id = nextID(lastID.pres_id) if lastID else "PRES0001"
    if fetchUser:
        if fetchMed:
            addPres = Prescriptions(
                pres_id=next_id,
                med_id=fetchMed.med_id,
                user_id=fetchUser.user_id,
                frequency=form["frequency"],
            expiry_date=datetime.strptime(form["expiry_date"], "%Y-%m-%d %H:%M:%S")
            )
            db.session.add(addPres)
            db.session.commit()
            return "Successfully Added", 200
        else:
            add_med_body = {
                "med_name": form["med_name"],
                "recommended_dosage": form["recommended_dosage"],
                "side_effects": form["side_effects"]
            }
            add_med = requests.post("http://localhost:8000/add-medicine", json=add_med_body)
            if add_med.status_code == 200:
                add_pres = requests.post("http://localhost:8000/add-prescription", json=form)
                if add_pres.status_code == 200:
                    return "Successfully Added", 200
                else:
                    return "Failed to add prescription", 500
    return "Unexpected Error", 500

@app.route("/delete-prescriptions", methods=["DELETE"])
def deletePrescriptions():
    form = request.get_json()
    fetchPres = Prescriptions.query.filter_by(pres_id=form["pres_id"], user_id=form["user_id"]).first()
    if fetchPres:
        db.session.delete(fetchPres)
        db.session.commit()
        return "Successfully Deleted", 200
    else:
        return "Prescription not found", 404

@app.route("/get-similar-names", methods=["GET"])
def get_similar_names():
    with app.app_context():
        medicine_names = db.session.query(Medicines.med_name).all()
        medicine_names = [name[0] for name in medicine_names]
    user_input = request.args.get("med_name","")
    matches = find_all_matches(user_input, medicine_names)
    return {"matches": matches}

@app.route("/transcribe", methods=["POST"])
def transcribe():
    form = request.get_json()
    prompt = f"""
        From the given text, extract the medicine name, frequency of intake, and the dates & times of intake.:
        {form["transcription"]}

        I want you to take the current time which is {datetime.now().strftime("%Y-%m-%d %H:%M:%S")} and based on the given times in the text give exact dates and times in the "times" key of the response json.
        The datetime format should be in yyyy-mm-dd HH:MM:SS.

        Return ONLY valid JSON with these keys:
        - "med_name" (string) [medicine name, rectify any minor spelling mistakes, Capitalise the first character]
        - "frequency" (integer, times per day) [frequency of intake per day]
        - "times" (list of time strings) [list of times in the format "yyyy-mm-dd HH:MM:SS"]
        - "recommended_dosage" (string) [recommended dosage of the medicine like 500gm or 1 tablet]
        - "side_effects" (string) [atmost 3 side effects of the medicine seperated by commas]

        Example input: "I have to take citrazine for 3 days at 5:00 p.m., 9:00 p.m., and 10:00 p.m. " [Given today is 2025-01-01]
        Example output:
        {{
            "med_name": "Citrazine",
            "frequency": 3,
            "times": ["2025-01-01 17:00:00", "2025-01-01 21:00:00", "2025-01-01 22:00:00", "2025-01-02 17:00:00", "2025-01-02 21:00:00", "2025-01-02 22:00:00", "2025-01-03 17:00:00", "2025-01-03 21:00:00", "2025-01-03 22:00:00"]
            "recommended_dosage": "500mg",
            "side_effects": "Drowsiness, Dry mouth, Dizziness"
        }}
        Incase the name of the medicine does not make any sense, return 'None' for that key, and for recommended_dosage, side_effects.
        Incase the frequency is not mentioned, return None for that key.
        Going with the logic that medicine is taken for 3 days, and the times are repeated each day.
        The times should be in 24-hour format.
        The times should be in the format "yyyy-mm-dd HH:MM:SS".
        In case of no medicine name or frequency, return None for that key.
    """
    response = gemini_model.generate_content(prompt)
    response = response.candidates[0].content.parts[0].text
    json_str = response.split('```json')[1].split('```')[0].strip()
    response = json.loads(json_str)
    # print(response, type(response))
    # response = eval(response.text)

    name_matches = requests.get(f"http://localhost:8000/get-similar-names?med_name={response['med_name']}").json()["matches"]
    response["similar-matches"] = [match[0] for match in name_matches]

    fetchMed = Medicines.query.filter_by(med_name=response["med_name"]).first()
    if fetchMed:
        response["recommended_dosage"] = fetchMed.recommended_dosage
        response["side_effects"] = fetchMed.side_effects
    else:
        response["recommended_dosage"] = response["recommended_dosage"] if response["recommended_dosage"]!='None' else ""
        response["side_effects"] = response["side_effects"] if response["side_effects"]!='None' else ""

    return response, 200

@app.route("/expiry-date-reader", methods=["POST"])
def expiry_date_reader():
    extracted_dates = []
    standardized_dates = []
    final_date = None

    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No file selected"}), 400

    try:
        # Read image bytes
        image_bytes = file.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # cv2.imshow("Uploaded Image", image)
        # cv2.waitKey(0)  # Wait for a key press to close
        # cv2.destroyAllWindows()

        if image is None:
            return jsonify({"error": "Invalid image"}), 400

        img_for_yolo = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        results = model(img_for_yolo)
        
        result_img = results[0].plot()  # This returns a numpy array
        _, result_buffer = cv2.imencode('.jpg', result_img)
        result_img_bytes = result_buffer.tobytes()
    
        boxes = results[0].boxes.xyxy.cpu().numpy() if hasattr(results[0].boxes, 'xyxy') else []
        cropped_images = []
        
        for box in boxes:
            x1, y1, x2, y2 = map(int, box)
            crop = image[y1:y2, x1:x2]
            if crop.size > 0:
                cropped_images.append(crop)

        for crop in cropped_images:
            crop_rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
            # Remove the cls parameter:
            ocr_result = ocr.ocr(crop_rgb)  # <-- Fixed line
            if ocr_result and len(ocr_result) > 0:
                for line in ocr_result[0]:
                    text = line[1][0]
                    extracted_dates.append(text)
                    std_date = standardize_medical_date(text)
                    if std_date:
                        standardized_dates.append(std_date)

        if standardized_dates:
            try:
                date_objs = [datetime.strptime(d, "%Y-%m-%d") for d in standardized_dates]
                max_date = max(date_objs)
                final_date = max_date.strftime("%Y-%m-%d")
            except Exception:
                final_date = standardized_dates[0] if standardized_dates else None


        print({
            "success": True,
            "detected_dates": extracted_dates,
            "standardized_dates": standardized_dates,
            "final_date": final_date,
            # "annotated_image": base64.b64encode(result_img_bytes).decode('utf-8') if result_img_bytes else None
        })  
        return {
            "success": True,
            "detected_dates": extracted_dates,
            "standardized_dates": standardized_dates,
            "final_date": final_date,
            # "annotated_image": base64.b64encode(result_img_bytes).decode('utf-8') if result_img_bytes else None
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }, 500


@app.route("/medicine-name-reader", methods=["POST"])
def medicine_name_reader():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No file selected"}), 400

    try:
        image_bytes = file.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if image is None:
            return jsonify({"error": "Invalid image"}), 400

        # Convert BGR (OpenCV) to RGB for OCR
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # Run OCR
        result = ocr.ocr(image_rgb)
        if not result or len(result) == 0:
            return jsonify({"error": "No text detected"}), 400

        extracted_text = [line[1][0] for line in result[0] if line[1][0].strip()]
        if not extracted_text:
            return jsonify({"error": "No usable text found"}), 400

        text_list = " - ".join(extracted_text)
        # Construct prompt for Gemini
        prompt = (
            f"""Given the following list of text strings extracted from a medicine package,
            identify which one(s) is/are the medicine name(s).
            You have to search within these texts and find the most probable medicine name.
            The name can be made up of multiple text strings. In that case you can combine them into one string for the medicine name. The names should sound like a medicine name, this is to avoid other necessary name being given as med name.
            The Med name should be in Proper Case. Meaning First Letter of each word should be Capitalized.
            Below is the list of text strings separated by ' - ':
            [{text_list}]
            Also you have to return the recommended dosage and side effects of the medicine.
            The side effects should be atmost 3 and seperated by commas.
            The recommended dosage (Summarise in max 6 words).
            Your response should be in JSON format with the following keys:
            SUMMARISE RECOMMENDED DOSAGE IN MAX 6 WORDS
            {{
                "medicine_name": medicine name,
                "recommended_dosage": recommended dosage (Summarise in max 6 words),
                "side_effects": side effects (atmost 3 side effects seperated by commas)
            }}
            if the name of the medicine does not make any sense, return 'None' for the recommended_dosage and side_effects.
            {{
                "medicine_name": "whatever you think is the medicine name",
                "recommended_dosage": "None",
                "side_effects": "None"
            }}"""
        )

        response = gemini_model.generate_content(prompt)
        print(response)
        response = response.candidates[0].content.parts[0].text
        print(response)
        json_str = response.split('```json')[1].split('```')[0].strip()
        response = json.loads(json_str)

        name_matches = requests.get(f"http://localhost:8000/get-similar-names?med_name={response['medicine_name']}").json()["matches"]
        response["similar-matches"] = [match[0] for match in name_matches]

        fetchMed = Medicines.query.filter_by(med_name=response["medicine_name"]).first()
        if fetchMed:
            response["recommended_dosage"] = fetchMed.recommended_dosage
            response["side_effects"] = fetchMed.side_effects
        else:
            response["recommended_dosage"] = response["recommended_dosage"] if response["recommended_dosage"]!='None' else ""
            response["side_effects"] = response["side_effects"] if response["side_effects"]!='None' else ""

        response["extracted_text"] = extracted_text
        response["success"] = True
        print(response)
        return response, 200

    except Exception as e:
        return jsonify({"error": f"Failed to process image: {str(e)}"}), 500


# Auxiliary functions
def nextID(id):
    prefix = id[:3]
    alpha = id[3]
    num = id[4:]
    if num == "9999":
        return f"{prefix}{chr(ord(alpha)+1)}0001"
    else:
        return f"{prefix}{alpha}{'0'*(4-len(str(int(num))))}{int(num)+1}"

def find_all_matches(user_input, medicines, top_n=5):
    matches = process.extract(user_input, medicines, scorer=fuzz.WRatio, limit=None)
    sorted_matches = sorted(matches, key=lambda x: x[1], reverse=True)
    if len(sorted_matches) > top_n:
        sorted_matches = sorted_matches[:top_n]
    return sorted_matches

def standardize_medical_date(date_str):
    # """
    # Robust date standardization that defaults to 1st day when no day is specified
    # Handles formats like:
    # - Dt:03/2023 → 2023-03-01
    # - EXP 12/25/2025 → 2025-12-25
    # - 15-02-2026 → 2026-02-15
    # - 2025.12 → 2025-12-01
    # - Dec 2025 → 2025-12-01
    # - 20251231 → 2025-12-31
    # """
    try:
        original_str = date_str
        date_str = date_str.lower()
        
        # Remove common prefixes/suffixes and normalize separators
        date_str = re.sub(r'(^dt[:]?|^exp|expiry|exp date|use by|best before)[:\s]*', '', date_str)
        date_str = re.sub(r'[\s\-_\.]', ' ', date_str).strip()
        date_str = re.sub(r'(\d)(st|nd|rd|th)\b', r'\1', date_str)
        
        # Try different date patterns
        patterns = [
            # Full dates with day
            (r'(\d{1,2}) (\d{1,2}) (\d{4})', lambda m: validate_and_format(m.group(3), m.group(2), m.group(1))),  # DD MM YYYY
            (r'(\d{1,2}) (\d{1,2}) (\d{4})', lambda m: validate_and_format(m.group(3), m.group(1), m.group(2))),  # MM DD YYYY
            (r'(\d{4}) (\d{1,2}) (\d{1,2})', lambda m: validate_and_format(m.group(1), m.group(2), m.group(3))),  # YYYY MM DD
            (r'(\w{3,}) (\d{1,2}),? (\d{4})', lambda m: format_month_name_date(m.group(1), m.group(2), m.group(3))),  # Month DD YYYY
            (r'(\d{1,2}) (\w{3,}) (\d{4})', lambda m: format_month_name_date(m.group(2), m.group(1), m.group(3))),  # DD Month YYYY
            
            # Month-year only (default to 1st day)
            (r'(\d{1,2}) (\d{4})', lambda m: f"{m.group(2)}-{int(m.group(1)):02d}-01"),  # MM YYYY
            (r'(\w{3,}) (\d{4})', lambda m: format_month_name_date(m.group(1), '1', m.group(2))),  # Month YYYY
            
            # Various separator formats
            (r'(\d{2})/(\d{2})/(\d{4})', lambda m: validate_and_format(m.group(3), m.group(2), m.group(1))),  # DD/MM/YYYY
            (r'(\d{2})/(\d{2})/(\d{4})', lambda m: validate_and_format(m.group(3), m.group(1), m.group(2))),  # MM/DD/YYYY
            (r'(\d{4})/(\d{2})/(\d{2})', lambda m: f"{m.group(1)}-{m.group(2)}-{m.group(3)}"),
            (r'(\d{2})/(\d{4})', lambda m: f"{m.group(2)}-{int(m.group(1)):02d}-01"),  # MM/YYYY
        ]
        
        for pattern, formatter in patterns:
            match = re.fullmatch(pattern, date_str)
            if match:
                try:
                    formatted_date = formatter(match)
                    if validate_date(formatted_date):
                        return formatted_date
                except (ValueError, IndexError):
                    continue
        
        # Fallback to more aggressive cleaning
        digits = re.sub(r'[^\d]', '', original_str)
        if len(digits) == 6:  # MMDDYY or DDMMYY
            return try_ambiguous_date(digits)
        elif len(digits) == 8:  # YYYYMMDD or MMDDYYYY
            return try_compact_date(digits)
        elif len(digits) in [4,5,6]:  # Partial dates
            return try_partial_date(digits)
            
        return None
        
    except Exception as e:
        print(f"Error standardizing date '{original_str}': {str(e)}")
        return None

def try_partial_date(digits):
    """Handle partial dates by defaulting to 1st day and first month if needed"""
    if len(digits) == 6:  # YYMMDD
        return f"20{digits[:2]}-{int(digits[2:4]):02d}-{int(digits[4:6]):02d}"
    elif len(digits) == 4:  # YYYY or MMDD
        if digits.isdigit():
            if 2000 <= int(digits) <= 2050:  # Likely year
                return f"{digits}-01-01"
            elif 1 <= int(digits[:2]) <= 12:  # Likely MMYY
                return f"20{digits[2:]}-{int(digits[:2]):02d}-01"
    return None

def format_month_name_date(month_str, day_str, year_str):
    """Format dates with month names"""
    month_map = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    }
    month = month_map.get(month_str[:3].lower())
    if month:
        return f"{year_str}-{month:02d}-{int(day_str):02d}"
    return None

def validate_date(date_str):
    """Validate that the date is reasonable (not in distant past/future)"""
    try:
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        current_year = datetime.now().year
        return 2000 <= date_obj.year <= current_year + 20
    except ValueError:
        return False

def validate_and_format(year, month, day):
    """Validate day/month ranges and format"""
    if 1 <= int(month) <= 12 and 1 <= int(day) <= 31:
        return f"{year}-{int(month):02d}-{int(day):02d}"
    return None

def try_ambiguous_date(digits):
    """Try to parse ambiguous 6-digit dates (MMDDYY or DDMMYY)"""
    # Try DDMMYY
    dd, mm, yy = int(digits[:2]), int(digits[2:4]), int(digits[4:])
    if 1 <= mm <= 12 and 1 <= dd <= 31:
        return f"20{yy:02d}-{mm:02d}-{dd:02d}"
    
    # Try MMDDYY
    mm, dd, yy = int(digits[:2]), int(digits[2:4]), int(digits[4:])
    if 1 <= mm <= 12 and 1 <= dd <= 31:
        return f"20{yy:02d}-{mm:02d}-{dd:02d}"
    
    return None

def try_compact_date(digits):
    """Try to parse 8-digit dates (YYYYMMDD or MMDDYYYY)"""
    # Try YYYYMMDD
    if digits[:4].isdigit() and 2000 <= int(digits[:4]) <= 2050:
        year, month, day = int(digits[:4]), int(digits[4:6]), int(digits[6:8])
        if 1 <= month <= 12 and 1 <= day <= 31:
            return f"{year}-{month:02d}-{day:02d}"
    
    # Try MMDDYYYY
    if digits[4:].isdigit() and 2000 <= int(digits[4:]) <= 2050:
        month, day, year = int(digits[:2]), int(digits[2:4]), int(digits[4:8])
        if 1 <= month <= 12 and 1 <= day <= 31:
            return f"{year}-{month:02d}-{day:02d}"
    
    return None
    


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8000)
