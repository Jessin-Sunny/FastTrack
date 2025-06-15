from flask import Flask, render_template, request, redirect, url_for, session,flash,send_file
import firebase_admin
from firebase_admin import credentials, auth, firestore
import random
import string
import os
from werkzeug.utils import secure_filename
from supabase import create_client
from flask import *
from datetime import timedelta
from flask_session import Session
import smtplib
from email.mime.text import MIMEText
from datetime import datetime
from google.cloud.firestore import GeoPoint
import pandas as pd
import zipfile
import qrcode
import io
import tempfile
import requests
from PIL import Image, ImageDraw, ImageFont
from dotenv import load_dotenv
load_dotenv()



# Initialize Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL")  # Replace with your Supabase project URL
SUPABASE_KEY = os.getenv("SUPABASE_KEY") # Replace with your Supabase API key
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY")  # Change this to a secure key
app.config['SESSION_TYPE'] = 'filesystem'  # Store session in filesystem
app.config['SESSION_FILE_DIR'] = './flask_session'  # Create a folder for session data
app.config['SESSION_PERMANENT'] = False  # Session persists only while user is active
Session(app)  # Initialize the session

# Firebase setup
cred_path = os.getenv("FIREBASE_CRED_PATH")
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)
db = firestore.client()

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS")
EMAIL_PASSWORD =  os.getenv("EMAIL_PASSWORD")

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user_id = request.form['Username']
        password = request.form['password']

        # 1️⃣ **Check if the user is an Admin**
        admin_ref = db.collection('Admin').document(user_id)
        admin_doc = admin_ref.get()

        if admin_doc.exists:
            admin = admin_doc.to_dict()
            print("Fetched admin:", admin)  # Debugging info

            if admin.get("A_Password") == password:  # Use hashing in production
                session["user"] = user_id
                session["admin_name"] = admin["A_Name"]
                session["user_type"] = "Admin"

                return redirect(url_for('Admindashboard'))  # Redirect to admin page
            else:
                flash("Invalid password", "error")
                return redirect(url_for('login'))

        # 2️⃣ **Check if the user is a Company**
        company_ref = db.collection('Company').document(user_id)
        company_doc = company_ref.get()

        if company_doc.exists:
            company = company_doc.to_dict()
            print("Fetched company:", company)  # Debugging info

            if company.get("C_Password") == password:  # Use hashing in production
                session["user"] = user_id
                session["company_name"] = company["C_Name"]
                session["user_type"] = "Company"
                session["company_id"] = user_id
                return redirect(url_for('dashboard'))  # Redirect to company dashboard
            else:
                flash("Invalid password", "error")
        else:
            flash("User not found", "error")

        return redirect(url_for('login'))

    return render_template('login.html')

@app.route('/Admindashboard')
def Admindashboard():
    if session.get("user_type") != "Admin":
        flash("Unauthorized access!", "error")
        return redirect(url_for('login'))
    
    return render_template('Admindashboard.html', admin_name=session["admin_name"])

@app.route('/CompanyD')
def CompanyD():
    if session.get("user_type") != "Company":
        return redirect(url_for('login')) 

    company_id = session.get('company_id')  # Get logged-in company ID from session

    if not company_id:
        flash("Company ID not found. Please log in again.", "error")
        return redirect(url_for('login'))

    # Fetch company details from Firestore
    company_ref = db.collection('Company').document(company_id)
    company_doc = company_ref.get()

    if not company_doc.exists:
        flash("Company details not found.", "error")
        return redirect(url_for('dashboard'))

    company_data = company_doc.to_dict()

    return render_template('CompanyD.html', company=company_data,company_id=company_id)


@app.route("/submit_issue", methods=["POST"])
def submit_issue():
    """Handles issue submission and stores it in Firestore."""
    try:
        issue_description = request.form.get("issueDescription", "").strip()
        email_consent = "email_consent" in request.form  # Checkbox returns True if checked, False otherwise

        if not issue_description:
            flash("⚠ Issue description is required!", "error")
            return redirect(url_for("dashboatd"))  # Redirect back to the form page

        issue_data = {
            "description": issue_description,
            "email_consent": email_consent,
            "status": "Pending"  # Default status
        }

        db.collection("Complaints").add(issue_data)  # Save issue in Firestore

        flash("✅ Issue submitted successfully!", "success")
        return redirect(url_for("dashboard"))  # Redirect to the main page

    except Exception as e:
        flash(f"❌ Error submitting issue: {str(e)}", "error")
        return redirect(url_for("dashboard"))
    
@app.route("/admin_complaints")
def admin_complaints():
    """Fetch issues from Firestore and render in HTML."""
    try:
        issues_ref = db.collection("Complaints").stream()
        complaints = [
            {
                "description": doc.to_dict().get("description"),
                "email_consent": doc.to_dict().get("email_consent", False),
                "status": doc.to_dict().get("status", "Pending")
            }
            for doc in issues_ref
        ]
        return render_template("AdminComplaints.html", complaints=complaints)

    except Exception as e:
        flash(f"❌ Error fetching complaints: {str(e)}", "error")
        return render_template("AdminComplaints.html", complaints=[])

def generate_employee_id(company_id):
    """Generates Employee ID using format: FD + 3 characters from company ID + random 3 digits"""
    company_code = company_id[2:5]  # Extract 3 characters from company ID
    random_digits = ''.join(random.choices(string.digits, k=3))
    return f"FD{company_code}{random_digits}"

def generate_password(employee_name):
    """Generates password: First 3 chars of name + special char + 4 random digits"""
    special_chars = "!@#$%^&*"
    emp_prefix = employee_name[:3].capitalize()  # First 3 chars capitalized
    special_char = random.choice(special_chars)
    random_digits = ''.join(random.choices(string.digits, k=4))
    return f"{emp_prefix}{special_char}{random_digits}"

@app.route('/EmployeeR', methods=['GET', 'POST'])
def EmployeeR():
    if request.method == 'POST':
        user_company_id = session.get("company_id")  # Ensure company is logged in
        if not user_company_id:
            flash("⚠ No company logged in!", "error")
            return redirect(url_for('login'))

        D_Name = request.form['D_Name']
        D_Email = request.form['D_Email']
        D_PhoneNo = request.form['D_PhoneNo']
        VehicleNo = request.form['VehicleNo']
        Vehicle_Type = request.form['Vehicle_Type']
        Capacity = int(request.form['Capacity'])

        # 🔹 Generate Employee ID & Password
        employee_id = generate_employee_id(user_company_id)
        password = generate_password(D_Name)

        # 🔹 Handle Profile Picture Upload
        profile_url = None
        if 'D_Profileurl' in request.files:
            profile_pic = request.files['D_Profileurl']
            if profile_pic.filename != '':
                filename = secure_filename(profile_pic.filename)
                storage_path = f"PersonnelProfile/{filename}"
                
                # Upload to Firebase Storage
                bucket = storage.bucket()
                blob = bucket.blob(storage_path)
                blob.upload_from_file(profile_pic, content_type=profile_pic.content_type)
                
                profile_url = blob.public_url  # Get public URL

        # 🔹 Employee Data to Firestore
        employee_data = {
            "D_Name": D_Name,
            "D_Email": D_Email,
            "D_PhoneNo": D_PhoneNo,
            "VehicleNo": VehicleNo,
            "Vehicle_Type": Vehicle_Type,
            "Capacity": Capacity,
            "D_Password": password,
            "D_Profileurl": profile_url if profile_url else "",
            "Selected_Today": False,
            "Password_Reset": False
        }

        db.collection("DeliveryPersonnel").document(employee_id).set(employee_data)

        flash(f"✅ Employee {D_Name} registered successfully! ID: {employee_id}", "success")
        return redirect(url_for('EmployeeR'))

    return render_template('EmployeeR.html')

@app.route('/terms')
def terms():
    return render_template('Terms.html')

@app.route('/privacy')
def privacy():
    return render_template('privacy.html')

@app.route('/editprof',methods=['GET', 'POST'])
def editprof():
    if session.get("user_type") != "Company":  # ✅ Only companies can access
        flash("Unauthorized access!", "error")
        return redirect(url_for('login'))
    
    company_id = session.get('company_id')
    company_ref = db.collection('Company').document(company_id)
    
    if request.method == 'POST':
        updated_data = {
            "C_Name": request.form.get('companyName'),
            "C_Address": request.form.get('address'),
            "C_Email": request.form.get('email'),
            "C_PhoneNo": request.form.get('phoneNumber'),
            "Type": request.form.get('type'),
            "Category": request.form.get('category'),
            "C_City": request.form.get('city'),
            "C_State": request.form.get('state'),
            "CINNO": request.form.get('cinNumber'),
            "PANNO": request.form.get('panNumber')
        }
        company_ref.update(updated_data)
        flash("Company details updated successfully!", "success")
        return redirect(url_for('editprof'))
    
    company_doc = company_ref.get()
    if not company_doc.exists:
        flash("Company details not found.", "error")
        return redirect(url_for('dashboard'))
    
    return render_template('editprof.html', company=company_doc.to_dict())

@app.route('/contact')
def contact():
    return render_template('contact.html')

@app.route('/about')
def about():
    return render_template('about.html')

@app.route('/Terms')
def Terms():
    return render_template('Terms.html')

@app.route('/EmployeeD')
def EmployeeD():
    if session.get("user_type") != "Company":
        return "Unauthorized Access", 403  # Ensure the company is logged in

    company_id = session['company_id']  # Example: "FC2B3"
    company_identifier = company_id[2:5]  # Extract characters 3,4,5 (e.g., "2B3")

    delivery_personnel_ref = db.collection('DeliveryPersonnel')
    docs = delivery_personnel_ref.stream()

    employees = []
    
    for doc in docs:
        doc_id = doc.id  # e.g., FD2B3108
        if len(doc_id) >= 5 and doc_id[:2] == "FD":  # Ensure valid ID format
            personnel_company_id = doc_id[2:5]  # Extract characters 3,4,5 (e.g., "2B3")
            
            if personnel_company_id == company_identifier:  # Filter by company
                data = doc.to_dict()
                employee = {
                    'ID': doc_id,
                    'Name': data.get('D_Name', 'N/A'),
                    'Phone': data.get('D_PhoneNo', 'N/A'),
                    'Email': data.get('D_Email', 'N/A'),
                    'Address': data.get('VehicleNo', 'N/A'),
                    'ProfileURL': data.get('D_Profileurl', '')  # Optional: for images
                }
                employees.append(employee)

    return render_template("EmployeeD.html", employees=employees)

@app.route('/package')
def package():
    if "company_id" not in session:  # Ensure company is logged in
        flash("Unauthorized access. Please log in.")
        return redirect(url_for('login'))

    company_id = session["company_id"]

    today_date = datetime.now().strftime("%Y-%m-%d")  # Get today's date as a Firestore document ID
    print(today_date)
    packages_ref = db.collection("Packages").document(today_date).collection(company_id).stream()

    packages = []
    for doc in packages_ref:
        package_data = doc.to_dict()
        package_data["Uploaded_Time"] = package_data["Uploaded_Time"]
        package_data["P_ID"] = doc.id # Convert Firestore timestamp
        packages.append(package_data)

    return render_template('package.html', packages=packages)

@app.route('/download_all_qr')
def download_all_qr():
    try:
        today_date = datetime.now().strftime("%Y-%m-%d")
        company_id = session.get("company_id")
        if not company_id:
            flash("❌ Error: Company ID not found. Please log in again.")
            return redirect(url_for("login"))
        
        package_ref = db.collection("Packages").document(today_date).collection(company_id)

        packages = package_ref.stream()
        if not packages:
            flash("No packages found for today.")
            return redirect(url_for('package'))  # Redirect back if no data

        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        zip_filename = temp_zip.name
        temp_zip.close()

        with zipfile.ZipFile(zip_filename, 'w') as zipf:
            for package in packages:
                package_data = package.to_dict()
                qr_url = package_data.get("QR_URL")

                if qr_url:
                    qr_filename = f"{package.id}.png"
                    qr_path = os.path.join(tempfile.gettempdir(), qr_filename)

                    response = requests.get(qr_url)
                    with open(qr_path, "wb") as f:
                        f.write(response.content)

                    zipf.write(qr_path, arcname=qr_filename)
                    os.remove(qr_path)  # Cleanup

        return send_file(zip_filename, as_attachment=True, download_name=f"QR_Codes_{today_date}.zip")

    except Exception as e:
        flash(f"❌ Error generating ZIP: {str(e)}")
        return redirect(url_for('package'))


@app.route('/Report')
def Report():
    return render_template('Report.html')

@app.route('/UploadPack', methods=['GET', 'POST'])
def UploadPack():
    if "company_id" not in session:  # Ensure company is logged in
        flash("Unauthorized access. Please log in.")
        return redirect(url_for('login'))

    company_id = session["company_id"]


    if request.method == 'POST':
        if 'uploaded-file' not in request.files:
            flash("No file part")
            print("⚠ No file found in request")
            return redirect(request.url)

        file = request.files['uploaded-file']
        if file.filename == '':
            flash("No selected file")
            print("⚠ No file selected")
            return redirect(request.url)

        if file:
            try:
                print("📂 File received:", file.filename)
                df = pd.read_excel(file)

                print("🔹 Read data from Excel:", df.head())  # Debugging Step

                today_date = datetime.now().strftime("%Y-%m-%d")
                package_ref = db.collection("Packages").document(today_date)

                remaining_ref = db.collection("RemainingPackages").where("Company_ID", "==", company_id).stream()
                remaining_packages = []
                for rem in remaining_ref:
                    rempackage_data= rem.to_dict()  
                    rempackage_data["Package_ID"] = rem.id  # ✅ Assign Firestore document ID as Package_ID
                    remaining_packages.append(rempackage_data)
                # Define quadrants
                quadrants = {"NE": [], "NW": [], "SW": [], "SE": []}

                # Define weight-size categories
                pack = {
                    "lvs": [], "ls": [], "lm": [], "ms": [], "mm": [],
                    "ll": [], "ml": [], "hs": [], "hm": [], "hl": [],
                    "hym": [], "hyl": []
                }

                # Define warehouse coordinates (assumed, modify as needed)
                warehouse_lat, warehouse_lon = 9.592641, 76.52212

                for _, row in df.iterrows():
                    package_id = row["P_ID"]
                    package_data = {
                        "Company_ID": company_id,
                        "Capacity": int(row["Capacity"]),
                        "Coordinates": GeoPoint(row["Coordinates_Latitude"], row["Coordinates_Longitude"]),
                        "Loc_Name": row["Loc_Name"],
                        "Uploaded_Time": datetime.now(),
                        "Weight": float(row["Weight"])
                    }

                    # Store package data in Firestore
                    package_ref.collection(company_id).document(package_id).set(package_data)

                    categorize_package(package_data, warehouse_lat, warehouse_lon, quadrants, pack,package_id)
                    # Generate and Upload QR Code to Supabase
                    qr_url = generate_and_upload_qr(package_id,company_id)  # Ensure this function returns a URL
                    if qr_url:
                        package_ref.collection(company_id).document(package_id).update({"QR_URL": qr_url})

                for package in remaining_packages:
                    categorize_package(package, warehouse_lat, warehouse_lon, quadrants, pack,package["Package_ID"])

                # 📌 Categorize by Vehicle Type (Bike & Truck)
                bike_packages = pack["lvs"] + pack["ls"] + pack["lm"] + pack["ms"] + pack["mm"]
                truck_packages = pack["ll"] + pack["ml"] + pack["hs"] + pack["hm"] + pack["hl"] + pack["hym"] + pack["hyl"]

                # 📌 Calculate total weight and size for both vehicle types
                total_weight_bike = sum(pkg["Weight"] for pkg in bike_packages)
                total_size_bike = sum(pkg["Capacity"] for pkg in bike_packages)

                print(total_weight_bike,total_size_bike)

                total_weight_truck = sum(pkg["Weight"] for pkg in truck_packages)
                total_size_truck = sum(pkg["Capacity"] for pkg in truck_packages)

                # 📌 Include Remaining Packages in Weight & Size Calculation
                for package in remaining_packages:
                    if package in bike_packages:
                        total_weight_bike += package["Weight"]
                        total_size_bike += package["Capacity"]
                    else:
                        total_weight_truck += package["Weight"]
                        total_size_truck += package["Capacity"]

                print("📌 FINAL QUADRANT ASSIGNMENT BEFORE EMPLOYEE CALCULATION:")
                for quad, packages in quadrants.items():
                    print(f"  🔹 {quad}: {len(packages)} packages")
                print(f"🚴 Bike-Eligible Packages: {len(bike_packages)}")
                print(f"🚛 Truck-Eligible Packages: {len(truck_packages)}")
                # Store these values in session for use in Empneed.html
                session["total_weight_bike"] = total_weight_bike
                session["total_size_bike"] = total_size_bike
                session["total_weight_truck"] = total_weight_truck
                session["total_size_truck"] = total_size_truck
                session["bike_packages"] = bike_packages
                session["truck_packages"] = truck_packages
                session["quadrants"] = quadrants 

                flash("✅ Package details & QR codes uploaded successfully!")
                print("✅ Data uploaded successfully!")

                print("✅ Redirecting to Empneed...")
                return redirect(url_for('Empneed'))

            except Exception as e:
                flash(f"❌ Error processing file: {str(e)}")
                print("❌ Error:", str(e))

            return redirect(url_for('UploadPack'))

    return render_template('UploadPack.html')

def categorize_package(package, warehouse_lat, warehouse_lon, quadrants, pack,package_id):
    """
    Categorizes a package based on its location (quadrant) and weight-size category.
    """
    package["Package_ID"] = package_id
    lat, lon = package["Coordinates"].latitude, package["Coordinates"].longitude
    weight, size = package["Weight"], package["Capacity"]

    # 📌 Assign Package to Quadrants
    if lat > warehouse_lat and lon > warehouse_lon:
        quadrants["NE"].append(package)
    elif lat > warehouse_lat and lon < warehouse_lon:
        quadrants["NW"].append(package)
    elif lat < warehouse_lat and lon < warehouse_lon:
        quadrants["SW"].append(package)
    elif lat < warehouse_lat and lon > warehouse_lon:
        quadrants["SE"].append(package)

    print(f"📍 Package {package['Loc_Name']} assigned to Quadrant: {list(quadrants.keys())[-1]}")
    # 📌 Categorize by Weight & Size
    if weight < 2 and size < 10:
        pack["lvs"].append(package)
    elif weight < 2 and 10< size < 30:
        pack["ls"].append(package)
    elif weight < 2 and 30 < size < 50:
        pack["lm"].append(package)
    elif 2 < weight < 5 and size < 30:
        pack["ms"].append(package)
    elif 2 < weight < 5 and 30<size < 50:
        pack["mm"].append(package)
    elif weight < 2 and size >= 50:
        pack["ll"].append(package)
    elif 2 < weight < 5 and size >= 50:
        pack["ml"].append(package)
    elif 5 < weight < 15 and size < 30:
        pack["hs"].append(package)
    elif 5 < weight < 15 and 30<size < 50:
        pack["hm"].append(package)
    elif 5 < weight < 15 and size >= 50:
        pack["hl"].append(package)
    elif weight > 15 and size < 50:
        pack["hym"].append(package)
    elif weight > 15 and size >= 50:
        pack["hyl"].append(package)

    print(f"✅ Categorized Package {package['Package_ID']} → Weight: {weight}, Size: {size}")


def generate_and_upload_qr(package_id,company_id):
    """Generates a QR code with the package ID written below it and uploads it to Supabase."""

    # Generate QR Code
    qr = qrcode.make(package_id)
    qr = qr.convert("RGB")  # Convert QR to RGB mode for text overlay
    draw = ImageDraw.Draw(qr)

    # Load a font (Use default if Arial is missing)
    try:
        font = ImageFont.truetype("arial.ttf", 20)  # Make sure Arial.ttf is installed
    except IOError:
        font = ImageFont.load_default()

    # Get text size using textbbox() instead of textsize()
    text_bbox = draw.textbbox((0, 0), package_id, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]

    # Create a new image with space for text
    img_width, img_height = qr.size
    new_height = img_height + text_height + 10  # Add padding for text
    new_img = Image.new("RGB", (img_width, new_height), "white")
    new_img.paste(qr, (0, 0))  # Paste QR code

    # Draw text below QR code
    text_position = ((img_width - text_width) // 2, img_height + 5)  # Center text
    draw = ImageDraw.Draw(new_img)
    draw.text(text_position, package_id, font=font, fill="black")

    # Save image to a temporary file
    fd, qr_path = tempfile.mkstemp(suffix=".png")
    os.close(fd)  # Close file descriptor before writing
    new_img.save(qr_path, format="PNG")

    try:
        # Upload to Supabase
        today_date = datetime.now().strftime("%Y-%m-%d")
        file_name = f"{today_date}/{company_id}/{package_id}.png"
        res = supabase.storage.from_("QRcodes").upload(file_name, qr_path, file_options={"content-type": "image/png"})

        # Get Public URL
        qr_url = supabase.storage.from_("QRcodes").get_public_url(file_name)

        return qr_url  # ✅ Return the public URL of the QR code
    finally:
        # Ensure the temporary file is deleted after upload
        os.remove(qr_path)

def generate_unique_company_id():
    """Generates a unique company ID in the format FCXXX"""
    while True:
        # Generate a 3-character ID (letters and digits)
        random_id = ''.join(random.choices(string.ascii_uppercase + string.digits, k=3))
        company_id = f"FC{random_id}"  # Prefix FC
        
        # Check if ID already exists in Firestore
        print(f"🔹 Checking Company ID: {company_id}")


        try:
            company_ref = db.collection('Company').document(company_id).get()
            if not company_ref.exists:
                print(f"✅ Generated Unique Company ID: {company_id}")
                return company_id
        except Exception as e:
            print(f"❌ Error Checking Firestore: {e}")

def generate_company_password(company_name):
    """Generates an 8-character password using the first 3 letters of the company name,
    a special character, and a random 4-digit number."""
    
    special_chars = "!@#$%^&*"
    first_three_letters = company_name[:3].upper()  # Take the first 3 letters in uppercase
    special_char = random.choice(special_chars)  # Pick a random special character
    random_digits = ''.join(random.choices(string.digits, k=4))  # Generate 4 random digits
    
    password = first_three_letters + special_char + random_digits  # Combine all parts
    return password


def upload_file(file, folder, filename):
    if file:
        file_path = f"{session['company_id']}/{filename}"  # Use generated company ID instead
  # Path in Supabase Storage
        
        # ✅ Read file contents into bytes
        file.stream.seek(0)  # Move to the beginning of the file
        file_data = file.stream.read()

        # ✅ Upload file as bytes instead of a file object
        response = supabase.storage.from_("FCdocuments").upload(file_path, file_data, file_options={"content-type": "application/pdf"})
        
        if response:
            public_url = supabase.storage.from_("FCdocuments").get_public_url(file_path)
            return public_url  # Return the public link
    return None


@app.route('/register', methods=['GET', 'POST'])
def register():
    print("🔹 Inside /register Route")
    
    if request.method == 'POST':
        print("🔹 Received POST request")

        if 'step' not in session:  # Step 1: Collect Basic Details
            print("🔹 Processing Step 1")
            
            session['C_Name'] = request.form.get('C_Name')
            session['CINNO'] = request.form.get('CINNO')
            session['PANNO'] = request.form.get('PANNO')
            session['C_Email'] = request.form.get('C_Email')
            session['C_PhoneNo'] = request.form.get('C_PhoneNo')
            session['C_Password'] = generate_company_password(session['C_Name'])

            print("✅ Step 1 Data:", session)

            if not all([session['C_Name'], session['CINNO'], session['PANNO'], session['C_Email'], session['C_PhoneNo'], session['C_Password']]):
                print("❌ Step 1 Failed: Missing Data")
                flash("All fields are required", "error")
                return redirect(url_for('register'))

            session['company_id'] = generate_unique_company_id()
            session['step'] = 2  # Move to Step 2
            print("✅ Step 1 Complete: Redirecting to Step 2")
            return redirect(url_for('register'))

        elif session.get('step') == 2:  # Step 2: Collect Address & Upload Files
            print("🔹 Processing Step 2")
            
            Type=request.form.get('Type')
            Category=request.form.get('Category')
            Country=request.form.get('Country')
            C_Address = request.form.get('C_Address')
            C_City = request.form.get('C_City')
            C_State = request.form.get('C_State')
            C_PIN = request.form.get('C_PIN')

            print(f"🔹 Address Data: {C_Address}, {C_City}, {C_State}, {C_PIN}")

            company_id = session.get('company_id')
            if not company_id:
                print("❌ Error: Company ID not generated")
                flash("Error: Company ID not generated.", "error")
                return redirect(url_for('register'))

            # Upload documents to Supabase
            certificate = request.files.get('certificate')
            pan = request.files.get('pan')
            address = request.files.get('address')

            print(f"🔹 Received Files: Certificate={certificate}, PAN={pan}, Address={address}")

            certificate_url = upload_file(certificate, company_id, "certificate.pdf")
            pan_url = upload_file(pan, company_id, "pan.pdf")
            address_url = upload_file(address, company_id, "address.pdf")

            print(f"✅ Uploaded Files: Certificate={certificate_url}, PAN={pan_url}, Address={address_url}")

            if not all([certificate_url, pan_url, address_url]):
                print("❌ File upload failed")
                flash("File upload failed, please try again.", "error")
                return redirect(url_for('register'))

            # Store data in Firestore
            db.collection('Company').document(company_id).set({
                'C_Name': session['C_Name'],
                'CINNO': session['CINNO'],
                'PANNO': session['PANNO'],
                'C_Email': session['C_Email'],
                'C_PhoneNo': session['C_PhoneNo'],
                'C_Password': session['C_Password'],
                'Type':Type,
                'Category':Category,
                'Country':Country,
                'C_Address': C_Address,
                'C_City': C_City,
                'C_State': C_State,
                'C_PIN': C_PIN,
                'Certificate_URL': certificate_url,
                'PAN_URL': pan_url,
                'Address_URL': address_url,
                'Verification_Status':'pending'
            })

            print("✅ Registration Completed. Redirecting to AfterReg")
            session.pop('step', None)
            session.pop('company_id', None)  # Clear session after completion
            return redirect(url_for('AfterReg'))

    print("🔹 GET Request: Checking session['step'] =", session.get('step'))

    if session.get('step') == 2:  # Show Step 2 form
        return render_template('register.html')

    return render_template('login.html')  # If no step detected, show login



@app.route('/AfterReg')
def AfterReg():
    return render_template('AfterReg.html')

@app.route('/dashboard')
def dashboard():
    if session.get("user_type") != "Company":
        flash("Unauthorized access!", "error")
        return redirect(url_for('login'))
    
    return render_template('dashboard.html', company_name=session["company_name"])


@app.route('/Empneed')
def Empneed():
    if "company_id" not in session:
        flash("Unauthorized access. Please log in.")
        return redirect(url_for('login'))

    company_id = session["company_id"]
    
    print("✅ Entered Empneed Route")

    # Fetch categorized packages from session
    bike_packages = session.get("bike_packages", [])
    truck_packages = session.get("truck_packages", [])
    quadrants = session.get("quadrants", {"NE": [], "NW": [], "SW": [], "SE": []})

    print(f"📌 Quadrants Data: {quadrants}")  # Check if quadrants exist
    print(f"📌 Bike Packages: {len(bike_packages)}")
    print(f"📌 Truck Packages: {len(truck_packages)}")

    # 🔥 Calculate number of employees needed
    try:
        bike_employees_needed, truck_employees_needed = calculate_employees(bike_packages, truck_packages, quadrants)
        print("🚀 Bike Employees Needed:", bike_employees_needed)
        print("🚀 Truck Employees Needed:", truck_employees_needed)
    except Exception as e:
        print(f"❌ Error in calculate_employees: {e}")
        return "Error in employee calculation", 500  # Return an error to stop infinite loading

    # Store in session for use in Empneed.html
    session["bike_employees_needed"] = bike_employees_needed
    session["truck_employees_needed"] = truck_employees_needed

    return render_template('Empneed.html', bike_employees_needed=bike_employees_needed, truck_employees_needed=truck_employees_needed)

# Constants
BIKE_WEIGHT_LIMIT = 20  # Max weight a bike can carry
BIKE_SIZE_LIMIT = 50     # Max size a bike can carry

TRUCK_WEIGHT_LIMIT = 100  # Max weight a truck can carry
TRUCK_SIZE_LIMIT = 200    # Max size a truck can carry

MAX_DISTANCE = 75000  # 75 km max travel distance
API_KEY = os.environ.get('MY_API_KEY')

def get_distance(coord1, coord2, mode="driving"):
    """
    Fetches the driving distance between two coordinates using Google Distance Matrix API.
    """
    lat1, lon1 = coord1.latitude, coord1.longitude
    lat2, lon2 = coord2.latitude, coord2.longitude

    url = f"https://maps.googleapis.com/maps/api/distancematrix/json?origins={lat1},{lon1}&destinations={lat2},{lon2}&mode={mode}&key={API_KEY}"

    try:
        response = requests.get(url)
        data = response.json()

        # ✅ Check if API response is valid
        if response.status_code != 200:
            print(f"⚠ API Error: {response.status_code} - {response.text}")
            return float('inf')

        if "rows" not in data or not data["rows"] or "elements" not in data["rows"][0] or not data["rows"][0]["elements"]:
            print(f"⚠ Invalid API Response Format: {data}")
            return float('inf')

        element = data["rows"][0]["elements"][0]
        if "distance" in element:
            return element["distance"]["value"]  # Distance in meters
        else:
            print(f"⚠ No distance data found in response: {element}")
            return float('inf')

    except Exception as e:
        print("⚠ API Request Failed:", e)
        return float('inf')


def optimize_destinations(assigned_packages):
    """
    Uses Nearest Neighbor Algorithm (NNA) to optimize delivery route.
    
    Input:
    - assigned_packages: List of packages assigned to an employee.

    Output:
    - last_location: The last delivery location in the optimized route.
    """
    if not assigned_packages:
        return None  # No packages assigned yet

    location_array = [pkg["Coordinates"] for pkg in assigned_packages]
    name_array = [pkg["Loc_Name"] for pkg in assigned_packages]

    l = len(location_array)
    optimized_location = []
    visited = [False] * l
    i = 0

    current_index = 0
    optimized_location.append(location_array[current_index])
    visited[current_index] = True

    while i < l - 1:
        min_distance = float('inf')
        next_index = None

        for j in range(l):
            if not visited[j]:
                distance = get_distance(location_array[current_index], location_array[j])
                if distance < min_distance:
                    min_distance = distance
                    next_index = j

        if next_index is not None:
            optimized_location.append(location_array[next_index])
            visited[next_index] = True
            current_index = next_index
        else:
            break

        i += 1

    return optimized_location[-1]  # Return last optimized location

def calculate_employees(bike_packages, truck_packages, quadrants):
    """
    Assigns packages to employees and calculates the number of employees needed.
    """
    print("🔍 Inside calculate_employees()")

    bike_employees_needed = 0
    truck_employees_needed = 0
    assigned_packages = {"bike": [], "truck": []}
    print(f"📌 Initial Quadrants Data: {quadrants}")
    print(bike_packages)
    
    # 🚴 Assign to bikes first (only from bike_packages)
    total_weight_bike = sum(pkg["Weight"] for pkg in bike_packages)
    total_size_bike = sum(pkg["Capacity"] for pkg in bike_packages)
    print(total_size_bike,total_weight_bike)
    print(f"⚡ Total Bike Weight: {total_weight_bike}, Total Bike Size: {total_size_bike}")
    while total_weight_bike > 0 and total_size_bike > 0:
        bike_employees_needed += 1
        remaining_weight = BIKE_WEIGHT_LIMIT
        remaining_size = BIKE_SIZE_LIMIT
        assigned = []
        assigned_in_this_loop = False

        i = 0
        while i < len(bike_packages):
            package = bike_packages[i]
            if package["Weight"] <= remaining_weight and package["Capacity"] <= remaining_size:
                assigned.append(package)
                remaining_weight -= package["Weight"]
                remaining_size -= package["Capacity"]
                total_weight_bike -= package["Weight"]
                total_size_bike -= package["Capacity"]
                bike_packages.pop(i)  # Remove assigned package
                assigned_in_this_loop = True
            else:
                i += 1  # Move to the next package if current one doesn't fit

        assigned_packages["bike"].append(assigned)
        if not assigned_in_this_loop:  # Stop if no package was assigned
            break

    # 🚛 Assign to trucks next (only from truck_packages)
    total_weight_truck = sum(pkg["Weight"] for pkg in truck_packages)
    total_size_truck = sum(pkg["Capacity"] for pkg in truck_packages)

    while total_weight_truck > 0 and total_size_truck > 0:
        truck_employees_needed += 1
        remaining_weight = TRUCK_WEIGHT_LIMIT
        remaining_size = TRUCK_SIZE_LIMIT
        assigned = []
        assigned_in_this_loop = False

        i = 0
        while i < len(truck_packages):
            package = truck_packages[i]
            if package["Weight"] <= remaining_weight and package["Capacity"] <= remaining_size:
                assigned.append(package)
                remaining_weight -= package["Weight"]
                remaining_size -= package["Capacity"]
                total_weight_truck -= package["Weight"]
                total_size_truck -= package["Capacity"]
                truck_packages.pop(i)  # Remove assigned package
                assigned_in_this_loop = True
            else:
                i += 1  # Move to next package

        assigned_packages["truck"].append(assigned)
        if not assigned_in_this_loop:  # Stop if no package was assigned
            break

    
    # ✅ Remove empty assignments
    assigned_packages["bike"] = [emp for emp in assigned_packages["bike"] if len(emp) > 0]
    assigned_packages["truck"] = [emp for emp in assigned_packages["truck"] if len(emp) > 0]

    # ✅ Update employee count after removing empty lists
    bike_employees_needed = len(assigned_packages["bike"])
    truck_employees_needed = len(assigned_packages["truck"])


    print(f"📌 FINAL EMPLOYEE ASSIGNMENT")
    for i, assigned in enumerate(assigned_packages["bike"]):
        print(f"🚴 Bike Employee {i+1}: {len(assigned)} packages")

    for i, assigned in enumerate(assigned_packages["truck"]):
        print(f"🚛 Truck Employee {i+1}: {len(assigned)} packages")

    session["assigned_packages"] = assigned_packages

    return bike_employees_needed, truck_employees_needed

# 🔹 **Function to Upload Remaining Packages to Firestore**
def store_remaining_packages(remaining_packages):
    """Stores leftover packages in Firestore under RemainingPackages collection."""
    if not remaining_packages:
        print("✅ No remaining truck packages to upload.")
        return

    # 🔹 Flatten if `remaining_packages` is a list of lists
    if isinstance(remaining_packages[0], list):
        remaining_packages = [pkg for sublist in remaining_packages for pkg in sublist]

    for package in remaining_packages:
        if not isinstance(package, dict):
            print(f"⚠ Invalid package format: {package}, skipping...")
            continue  # Skip non-dictionary items

        try:
            package_doc = db.collection("RemainingPackages").document(package["Package_ID"])
            package_doc.set({
                "Uploaded_Time": firestore.SERVER_TIMESTAMP,
                "Delivery_Location": package.get("Coordinates", "N/A"),
                "Dlocation_Name": package.get("Loc_Name", "Unknown"),
                "Pickup_Location": firestore.GeoPoint(9.592641, 76.52212),
                "QR_ID": package["Package_ID"],
                "Status": "Pending",
                "Plocation_Name": "Kottayam, Kerala, India"
            })
            print(f"📂 Package {package['Package_ID']} stored under RemainingPackages for next-day delivery.")
        except Exception as e:
            print(f"⚠ Error uploading remaining package {package.get('Package_ID', 'UNKNOWN')} to Firestore: {e}")

def calculate_truck_needed(remaining_bike_packages):
    if not remaining_bike_packages:
        return 0
    remaining_bike_packages = [pkg for sublist in remaining_bike_packages for pkg in sublist] if remaining_bike_packages and isinstance(remaining_bike_packages[0], list) else remaining_bike_packages

    total_weight = sum(pkg.get("Weight", 0) for pkg in remaining_bike_packages)
    total_size = sum(pkg.get("Capacity", 0) for pkg in remaining_bike_packages)
    return max(int(total_weight / TRUCK_WEIGHT_LIMIT), int(total_size / TRUCK_SIZE_LIMIT))

def get_daily_package_id():
    """
    Returns the document ID for today's package assignment in AssignedPackages.
    Instead of a random ID, we use a fixed format: "YYYY-MM-DD".
    """
    today_str = datetime.now().strftime("%Y-%m-%d")  # Example: "2025-03-08"
    
    assigned_packages_ref = db.collection("AssignedPackages").document(today_str)

    # 🔹 Check if document exists, otherwise create it
    if not assigned_packages_ref.get().exists:
        assigned_packages_ref.set({"date": today_str})  # Store today's date
    
    return today_str  # Return today's date as the document ID


@app.route('/SelectBE', methods=['GET', 'POST'])
def SelectBE():
    user_company_id = session.get("company_id")
    if not user_company_id:
        flash("⚠ No company logged in!")
        return redirect(url_for('login'))
    
    print("\n✅ Entered SelectBE Route")
    
    employees_ref = db.collection("DeliveryPersonnel").where("Vehicle_Type", "==", "Bike").stream()
    employees = []
    
    for emp_doc in employees_ref:
        emp_data = emp_doc.to_dict()
        emp_id = emp_doc.id
        if len(emp_id) >= 5:
            emp_company_id = "FC" + emp_id[2:5]
            if emp_company_id == user_company_id:
                emp_data["D_ID"] = emp_id
                employees.append(emp_data)
    
    truck_employees_needed = session.get("truck_employees_needed", 0)
    print(f"🔹 Initial Truck Employees Required: {truck_employees_needed}")
    
    if request.method == 'POST':
        selected_employees = request.form.getlist("employees")
        print(f"🚴 Selected Bike Employees: {selected_employees}")
        
        for emp in employees:
            emp_ref = db.collection("DeliveryPersonnel").document(emp["D_ID"])
            emp_selected = emp["D_ID"] in selected_employees
            emp_ref.update({"Selected_Today": emp_selected})
        
        assigned_packages = session.get("assigned_packages", {"bike": [], "truck": []})
        remaining_bike_packages = []
        
        # 🚴 **Assign bike packages**  
        if len(assigned_packages["bike"]) == len(selected_employees):
            assign_to_employees(assigned_packages["bike"], selected_employees, user_company_id)
        else:
            assign_to_employees(assigned_packages["bike"][:len(selected_employees)], selected_employees, user_company_id)
            remaining_bike_packages = assigned_packages["bike"][len(selected_employees):]

        # 🚛 **Reassign remaining bike packages to trucks if needed**
        truck_employees_needed += calculate_truck_needed(remaining_bike_packages)
        session["remaining_bike_packages"] = remaining_bike_packages
        session["truck_employees_needed"] = truck_employees_needed

        print(f"🚛 Updated Truck Employees Needed: {truck_employees_needed}")
        flash("✅ Employees assigned successfully!")
        return redirect(url_for('SelectTE'))
    
    return render_template("SelectBE.html", employees=employees)


@app.route('/SelectTE', methods=['GET', 'POST'])
def SelectTE():
    user_company_id = session.get("company_id")
    if not user_company_id:
        flash("⚠ No company logged in!")
        return redirect(url_for('login'))
    
    truck_employees_needed = session.get("truck_employees_needed", 0)
    print(f"✅ Entered SelectTE Route - Truck Employees Required: {truck_employees_needed}")
    
    employees_ref = db.collection("DeliveryPersonnel").where("Vehicle_Type", "==", "Truck").stream()
    employees = []

    for emp_doc in employees_ref:
        emp_data = emp_doc.to_dict()
        emp_id = emp_doc.id
        if len(emp_id) >= 5:
            emp_company_id = "FC" + emp_id[2:5]
            if emp_company_id == user_company_id:
                emp_data["D_ID"] = emp_id
                employees.append(emp_data)

    available_employeesT = len(employees)
    print(f"📌 Available Truck Employees: {available_employeesT}")
    
    if request.method == 'POST':
        selected_employees = request.form.getlist("employees")
        print(f"🚛 Selected Truck Employees: {selected_employees}")
        
        for emp in employees:
            emp_ref = db.collection("DeliveryPersonnel").document(emp["D_ID"])
            emp_selected = emp["D_ID"] in selected_employees
            emp_ref.update({"Selected_Today": emp_selected})
        
        assigned_packages = session.get("assigned_packages", {"bike": [], "truck": []})
        remaining_truck_packages = []

        # 🚛 **Assign remaining bike packages to truck employees first**
        remaining_bike_packages = session.get("remaining_bike_packages", [])
        if remaining_bike_packages and selected_employees:
            assign_to_employees(remaining_bike_packages, selected_employees, user_company_id)
            remaining_bike_packages = []  # Mark as assigned

        # 🚛 **Assign truck packages**
        if selected_employees:
            if truck_employees_needed >= available_employeesT:
                assign_to_employees(assigned_packages["truck"], selected_employees, user_company_id)
            else:
                assign_to_employees(assigned_packages["truck"][:available_employeesT], selected_employees, user_company_id)
                remaining_truck_packages = assigned_packages["truck"][available_employeesT:]
        else:
            print("⚠ No truck employees selected! Moving all unassigned packages to Firestore.")
            remaining_truck_packages = assigned_packages["truck"]

        # 🔹 **Store unassigned packages in Firestore (`RemainingPackages`)**
        total_remaining_packages = remaining_truck_packages + remaining_bike_packages
        if total_remaining_packages:
            print(f"📂 Storing {len(total_remaining_packages)} remaining packages in Firestore...")
            store_remaining_packages(total_remaining_packages)

        # ✅ Final cleanup before redirect
        session["remaining_bike_packages"] = []
        session["remaining_truck_packages"] = []

        flash("✅ Employees assigned successfully!")
        return redirect(url_for('dashboard'))
    
    return render_template("SelectTE.html", employees=employees, truck_employees_needed=truck_employees_needed)


def assign_to_employees(packages, employees, company_id):
    """
    Assigns packages to employees using the structure created in calculate_employees().
    Avoids recalculating assignments and maintains quadrant priority.
    """
    if not employees or not packages:
        print("⚠ No employees or assigned packages available for assignment!")
        return

    daily_doc_id = get_daily_package_id()  # Get today's document ID

    print("📦 Assigning packages to employees based on calculated assignment...")

    if len(employees) != len(packages):
        print(f"⚠ Mismatch: {len(employees)} employees but {len(packages)} assigned package groups!")

    for i, emp_id in enumerate(employees):
        if i >= len(packages):
            print(f"⚠ No assigned packages for employee {emp_id}, skipping...")
            continue

        employee_packages = packages[i]  # Get assigned packages for this employee
        print(f"✅ Assigning {len(employee_packages)} packages to {emp_id}")

        for package in employee_packages:
            if not isinstance(package, dict):
                print(f"⚠ Skipping invalid package: {package}")
                continue  # Skip non-dictionary items

            package_doc = (
                db.collection("AssignedPackages")
                .document(daily_doc_id)
                .collection("DeliveryPersonnels")
                .document(emp_id)
                .collection("Packages")
                .document(package["Package_ID"])
            )

            package_doc.set({
                "Assigned_Time": firestore.SERVER_TIMESTAMP,
                "Delivery_Location": package.get("Coordinates", "N/A"),
                "Dlocation_Name": package.get("Loc_Name", "Unknown"),
                "Pickup_Location": firestore.GeoPoint(9.592641, 76.52212),
                "QR_ID": package["Package_ID"],
                "Status": "Pending",
                "Plocation_Name": "Kottayam, Kerala, India"
            })

            print(f"📦 Package {package['Package_ID']} assigned to {emp_id}")

    print("🚚 Package assignment completed successfully!")
import pytz
@app.route('/EmployeePD')
def EmployeePD():
    try:
        employees = []
        
        # 🔹 Get logged-in company's ID from session
        company_id = session.get('company_id')  

        if not company_id or len(company_id) < 5:
            return "Unauthorized access: Invalid Company ID", 403

        # 🔹 Extract characters at index 2, 3, and 4 from company_id
        company_substring = company_id[2:5]

        # 🔹 Set timezone and get today's date
        local_tz = pytz.timezone('Asia/Kolkata')
        current_date = datetime.now(local_tz).strftime('%Y-%m-%d')

        print(f"🔍 Checking Firestore for assigned packages on: {current_date} for company {company_id} (matching ID pattern: {company_substring})")

        # 🔹 Get all delivery personnel and filter manually based on ID pattern
        personnel_ref = db.collection('DeliveryPersonnel')
        personnel_docs = personnel_ref.stream()

        for person in personnel_docs:
            person_data = person.to_dict()
            person_id = person.id

            # 🔹 Match if the characters at index 2,3,4 in person_id match the company_id pattern
            if len(person_id) >= 5 and person_id[2:5] == company_substring:
                print(f"📌 Matched employee: {person_id} (Company ID match: {company_substring})")

                # 🔹 Check if this employee has assigned packages today
                packages_ref = (
                    db.collection("AssignedPackages")
                    .document(current_date)
                    .collection("DeliveryPersonnels")
                    .document(person_id)
                    .collection("Packages")
                )

                try:
                    packages_docs = list(packages_ref.stream())  # Force list to debug
                    if not packages_docs:
                        print(f"❌ No packages found for employee {person_id}")
                except Exception as e:
                    print(f"❌ Firestore error fetching packages for {person_id}: {e}")
                    packages_docs = []

                packages = []
                for package in packages_docs:
                    package_data = package.to_dict()
                    print(f"📦 Found package {package.id} for employee {person_id}")
                    packages.append({
                        'package_id': package.id,
                        'customer_name': package_data.get('C_Name', ''),
                        'address': package_data.get('C_Address', ''),
                        'phone': package_data.get('C_PhoneNo', ''),
                        'status': package_data.get('Status', 'Pending')
                    })

                employees.append({
                    'id': person_id,
                    'name': person_data.get('D_Name', ''),
                    'email': person_data.get('D_Email', ''),
                    'phone': person_data.get('D_PhoneNo', ''),
                    'vehicle': person_data.get('VehicleNo', ''),
                    'capacity': person_data.get('Capacity', 0),
                    'profile_url': person_data.get('D_Profileurl', ''),
                    'packages': packages,
                    'package_count': len(packages)
                })

        print("✅ Final employee list:", employees)

        return render_template('EmployeePD.html', employees=employees)

    except Exception as e:
        print(f"❌ ERROR: {e}")
        return f"An error occurred: {str(e)}", 500



@app.route('/logout')
def logout():
    session.clear()  # Clears all session data
    flash("You have been logged out.", "info")
    return redirect(url_for('login'))

@app.route('/AdminCV')
def AdminCV():
    """Fetches companies with pending verification and displays them."""
    companies_ref = db.collection('Company').where("Verification_Status", "==", "pending").stream()

    companies = []
    for doc in companies_ref:
        company_data = doc.to_dict()
        companies.append({
            "doc_id": doc.id,  
            "CINNO": company_data.get("CINNO", "N/A"),
            "C_Name": company_data.get("C_Name", "N/A"),
            "Logo_URL": company_data.get("Logo_URL", "https://via.placeholder.com/100"), 
        })

    return render_template('AdminCV.html', companies=companies)

@app.route('/AdminV', methods=['POST'])
def AdminV():
    """Fetch full details of a company using its `doc_id`."""
    doc_id = request.form.get('doc_id')

    if not doc_id:
        return "Invalid request", 400

    company_ref = db.collection('Company').document(doc_id)
    company_doc = company_ref.get()

    if not company_doc.exists:
        return "Company not found", 404

    company_data = company_doc.to_dict()
    company_data["doc_id"] = doc_id  # Preserve doc_id for verification
    return render_template('AdminV.html', company=company_data)


@app.route('/get_pending_companies')
def get_pending_companies():
    """Fetch the count of companies with 'pending' verification status."""
    companies_ref = db.collection('Company').where('Verification_Status', '==', 'pending').stream()
    pending_count = sum(1 for _ in companies_ref)  # Count pending companies

    return jsonify({"pending_count": pending_count})

# Function to Send Email
def send_email(subject, body, recipient_email):
    msg = MIMEText(body, "plain")
    msg['Subject'] = subject
    msg['From'] = EMAIL_ADDRESS
    msg['To'] = recipient_email

    try:
        print(f"📧 Sending email to: {recipient_email}")
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
        server.sendmail(EMAIL_ADDRESS, recipient_email, msg.as_string())
        server.quit()
        print("✅ Email sent successfully!")
        return True
    except Exception as e:
        print(f"❌ Email sending failed: {e}")
        return False

@app.route('/verify_company', methods=['POST'])
def verify_company():
    """Verify company, update Firebase, and send login credentials via email."""
    doc_id = request.form.get("doc_id")

    company_ref = db.collection('Company').document(doc_id)
    company_doc = company_ref.get()

    if not company_doc.exists:
        return jsonify({"error": "Company not found"}), 404

    company_data = company_doc.to_dict()
    company_name = company_data.get("C_Name")
    email = company_data.get("C_Email")
    company_id = company_data.get("CINNO")  # Use CINNO as company ID
    password = company_data.get("C_Password")

    # ✅ Update Firestore to mark as verified
    company_ref.update({"Verification_Status": "verified"})

    # ✅ Email Content
    subject = "Company Registration Approved - FASTTRACK"
    body = f"""
    Dear {company_name},

    Your company registration has been successfully verified!

    **Login Details:**
    - **Login ID**: {doc_id}
    - **Password**: {password}

    You can now log in using these credentials.

    Regards,  
    FASTTRACK Admin
    """

    if send_email(subject, body, email):
        return redirect(url_for('AdminCV'))  # Refresh AdminV page
    else:
        return jsonify({"error": "Email sending failed."}), 500



# Route to Reject Company
@app.route('/reject_company', methods=['POST'])
def reject_company():
    """Rejects a company and updates its verification status instead of deleting."""
    doc_id = request.form.get("doc_id")

    company_ref = db.collection('Company').document(doc_id)
    company_doc = company_ref.get()

    if not company_doc.exists:
        return jsonify({"error": "Company not found"}), 404

    company_data = company_doc.to_dict()
    email = company_data.get("C_Email")
    company_name = company_data.get("C_Name")

    # ✅ Update Firestore to mark as rejected
    company_ref.update({"Verification_Status": "rejected"})

    # ✅ Email Content
    subject = "Company Registration Rejected - FASTTRACK"
    body = f"""
    Dear {company_name},

    Your company registration has been rejected due to incorrect details.  
    Please re-register with the correct information.

    Regards,  
    FASTTRACK Admin
    """

    if send_email(subject, body, email):
        return redirect(url_for('AdminCV'))  # Refresh AdminV page
    else:
        return jsonify({"error": "Email sending failed."}), 500
    
@app.route('/AdminRC')
def AdminRC():
    """Fetches companies with verified status and passes them to the template."""
    companies_ref = db.collection('Company').where("Verification_Status", "==", "verified").stream()

    companies = []
    for doc in companies_ref:
        company_data = doc.to_dict()
        companies.append({
            "doc_id": doc.id,  # Firestore document ID
            "CINNO": company_data.get("CINNO", "N/A"),
            "C_Name": company_data.get("C_Name", "N/A"),
            "Logo_URL": company_data.get("Logo_URL", "https://via.placeholder.com/100"),  # Default image
        })
    print(f"🔹 Fetched {len(companies)} verified companies")

    return render_template('AdminRC.html', companies=companies)

@app.route('/AdminCD', methods=['POST'])
def AdminCD():
    """Fetch a single company's details using CIN number."""
    cin = request.form.get('cinno')  # Get CIN from form data

    if not cin:
        return "Invalid request", 400  # Handle missing CIN

    company_ref = db.collection("Company").document(cin)
    company_doc = company_ref.get()

    if not company_doc.exists:
        return "Company not found", 404  # Handle non-existent company

    company_data = company_doc.to_dict()
    return render_template('AdminCD.html', company=company_data)

@app.route('/AdminApp')
def AdminApp():
    return render_template('AdminApp.html')

@app.route('/AdminComplaints')
def AdminComplaints():
    return render_template('AdminComplaints.html')

@app.route('/AdminReport')
def AdminReport():
    return render_template('AdminReport.html')

if __name__ == '__main__':
    app.run(debug=True)
