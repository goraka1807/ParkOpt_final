
from pathlib import Path
import qrcode

# Save images inside backend/qr-codes
output_dir = Path(__file__).parent / "backend" / "qr-codes"
output_dir.mkdir(parents=True, exist_ok=True)

parking_spaces = {
    "Baner_EV_BAN-01": "parkopt_space_BanerEV00001",
    "Hinjawadi_HIN-01": "parkopt_space_Hinjawadi001",
    "Koregaon_Park_KP-01": "parkopt_space_KoregaonPark01",
    "Pune_Station_PST-01": "parkopt_space_PuneStation01",
    "Shivajinagar_SHV-01": "parkopt_space_Shivajinagar01",
    "Wakad_WAK-01": "parkopt_space_Wakad0000001",
}

for filename, qr_text in parking_spaces.items():
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=4,
    )

    qr.add_data(qr_text)
    qr.make(fit=True)

    image = qr.make_image(
        fill_color="black",
        back_color="white"
    )

    file_path = output_dir / f"{filename}.png"
    image.save(file_path)

    print(f"Generated: {file_path}")

print("\nAll 6 parking QR codes generated successfully!")
