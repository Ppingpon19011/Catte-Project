import 'package:flutter/material.dart';
import '../utils/theme_config.dart';
import '../widgets/custom_card.dart';

class UserGuideScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('วิธีการใช้งาน'),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildIntroductionSection(),
          SizedBox(height: 20),
          _buildWeightEstimationGuide(),
          SizedBox(height: 20),
          _buildCattleManagementGuide(),
          SizedBox(height: 20),
          _buildManualMeasurementGuide(),
          SizedBox(height: 20),
          _buildDataManagementGuide(),
          SizedBox(height: 20),
          _buildTroubleshootingGuide(),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildIntroductionSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'แนะนำแอปพลิเคชัน',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDarkColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'แอปพลิเคชันประมาณน้ำหนักโคด้วยภาพถ่ายช่วยให้คุณสามารถประมาณน้ำหนักของโคได้โดยใช้เพียงภาพถ่าย แอปพลิเคชันนี้ใช้เทคโนโลยี AI เพื่อตรวจจับจุดสำคัญในภาพโค และคำนวณน้ำหนักโดยประมาณจากการวัดรอบอกและความยาวลำตัว',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'กรุณาอ่านคำแนะนำทั้งหมดเพื่อให้ได้ผลลัพธ์ที่แม่นยำที่สุด',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightEstimationGuide() {
    return DetailCard(
      title: 'การประมาณน้ำหนักโค',
      children: [
        _buildGuideStep(
          number: 1,
          title: 'ถ่ายภาพโค',
          description: 'ถ่ายภาพโคจากด้านข้างให้เห็นลำตัวโดยสมบูรณ์ ควรถ่ายในระยะห่างประมาณ 2-3 เมตร และในที่ที่มีแสงสว่างเพียงพอ',
          icon: Icons.camera_alt,
        ),
        _buildGuideStep(
          number: 2,
          title: 'จุดอ้างอิง',
          description: 'วางวัตถุอ้างอิงที่ทราบขนาดแน่นอน (เช่น ไม้ขนาด 100 ซม.ที่พันเทปเหลืองตรงปลายทั้ง 2 ด้าน) ใกล้กับโค เพื่อช่วยในการคำนวณขนาดที่แท้จริง',
          icon: Icons.straighten,
        ),
        _buildGuideStep(
          number: 3,
          title: 'ประมวลผลอัตโนมัติ',
          description: 'แอปจะพยายามตรวจจับจุดสำคัญโดยอัตโนมัติ ได้แก่ จุดอ้างอิง (สีเหลือง), รอบอก (สีแดง), และความยาวลำตัว (สีน้ำเงิน)',
          icon: Icons.auto_awesome,
        ),
        _buildGuideStep(
          number: 4,
          title: 'ปรับแต่งด้วยตนเอง',
          description: 'หากการตรวจจับอัตโนมัติไม่สมบูรณ์ คุณสามารถปรับตำแหน่งจุดวัดด้วยตนเองได้โดยใช้เครื่องมือวัดในแอป',
          icon: Icons.edit,
        ),
        _buildGuideStep(
          number: 5,
          title: 'บันทึกผล',
          description: 'หลังจากได้ผลการประมาณน้ำหนักแล้ว คุณสามารถบันทึกไว้ในประวัติน้ำหนักของโคแต่ละตัวได้',
          icon: Icons.save,
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'เคล็ดลับ: ถ่ายภาพในแนวนอนและให้โคยืนตรงขนานกับจุดอ้างอิงเพื่อความแม่นยำสูงสุด',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCattleManagementGuide() {
    return DetailCard(
      title: 'การจัดการข้อมูลโค',
      children: [
        _buildGuideStep(
          number: 1,
          title: 'เพิ่มโคใหม่',
          description: 'กดปุ่ม "เพิ่มโคใหม่" ที่หน้าหลัก กรอกข้อมูลพื้นฐานของโค เช่น ชื่อ หมายเลข สายพันธุ์ เพศ วันเกิด และข้อมูลอื่นๆ',
          icon: Icons.add_circle_outline,
        ),
        _buildGuideStep(
          number: 2,
          title: 'แก้ไขข้อมูลโค',
          description: 'กดที่รายการโคที่ต้องการ แล้วกดปุ่มแก้ไขที่หน้ารายละเอียด คุณสามารถแก้ไขข้อมูลได้ตามต้องการ',
          icon: Icons.edit_note,
        ),
        _buildGuideStep(
          number: 3,
          title: 'ลบข้อมูลโค',
          description: 'มีสองวิธี: 1) ปัดรายการโคไปทางซ้ายในหน้ารายการ หรือ 2) กดปุ่มลบที่ด้านล่างของหน้ารายละเอียดโค',
          icon: Icons.delete_outline,
        ),
      ],
    );
  }

  Widget _buildManualMeasurementGuide() {
    return DetailCard(
      title: 'การวัดด้วยตนเอง',
      children: [
        _buildGuideStep(
          number: 1,
          title: 'เข้าสู่โหมดวัดด้วยตนเอง',
          description: 'หากการตรวจจับอัตโนมัติไม่สมบูรณ์ กดปุ่ม "วัดด้วยตนเอง" เพื่อเข้าสู่หน้าการวัดแบบละเอียด',
          icon: Icons.touch_app,
        ),
        _buildGuideStep(
          number: 2,
          title: 'จัดการเส้นวัดระยะ',
          description: 'มี 3 เส้นที่ต้องวัด: จุดอ้างอิง (สีเหลือง), รอบอก (สีแดง), และความยาวลำตัว (สีน้ำเงิน) แตะที่หมุดและลากเพื่อปรับตำแหน่ง',
          icon: Icons.straighten,
        ),
        _buildGuideStep(
          number: 3,
          title: 'ยืนยันการวัด',
          description: 'เมื่อจัดวางเส้นถูกต้องแล้ว กดปุ่ม "บันทึก" ด้านล่างเพื่อยืนยันการวัดและคำนวณน้ำหนัก',
          icon: Icons.check_circle_outline,
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'หมายเหตุ: การวัดด้วยตนเองมักให้ผลลัพธ์ที่แม่นยำกว่าเมื่อการตรวจจับอัตโนมัติไม่สมบูรณ์',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataManagementGuide() {
    return DetailCard(
      title: 'การจัดการข้อมูลน้ำหนัก',
      children: [
        _buildGuideStep(
          number: 1,
          title: 'ดูประวัติน้ำหนัก',
          description: 'เลือกโคที่ต้องการ แล้วกดแท็บ "ประวัติการชั่งน้ำหนัก" เพื่อดูประวัติการชั่งน้ำหนักทั้งหมด',
          icon: Icons.history,
        ),
        _buildGuideStep(
          number: 2,
          title: 'ดูกราฟน้ำหนัก',
          description: 'กดที่ไอคอนกราฟในหน้าประวัติน้ำหนักเพื่อดูกราฟการเติบโตของโคตามเวลา',
          icon: Icons.trending_up,
        ),
        _buildGuideStep(
          number: 3,
          title: 'เปรียบเทียบกับค่าเฉลี่ย',
          description: 'ใช้ฟีเจอร์เปรียบเทียบเพื่อดูว่าน้ำหนักของโคเทียบกับค่าเฉลี่ยตามสายพันธุ์และอายุเป็นอย่างไร',
          icon: Icons.compare_arrows,
        ),
        _buildGuideStep(
          number: 4,
          title: 'ส่งออกข้อมูล',
          description: 'คุณสามารถส่งออกข้อมูลประวัติน้ำหนักเป็นไฟล์ CSV เพื่อใช้ในโปรแกรมอื่นๆ ได้',
          icon: Icons.file_download,
        ),
      ],
    );
  }

  Widget _buildTroubleshootingGuide() {
    return DetailCard(
      title: 'การแก้ไขปัญหาเบื้องต้น',
      children: [
        Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'ตรวจจับภาพไม่สำเร็จ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• ตรวจสอบว่าภาพมีแสงสว่างเพียงพอ\n• ตรวจสอบว่าโคยืนตรงและเห็นด้านข้างเต็มตัว\n• มีวัตถุอ้างอิงขนาด 100 ซม. ในภาพ\n• ลองใช้การวัดด้วยตนเองแทน',
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[800]),
                  SizedBox(width: 8),
                  Text(
                    'น้ำหนักไม่ตรงกับความเป็นจริง',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• ตรวจสอบตำแหน่งของเส้นวัดให้ถูกต้อง\n• ตรวจสอบว่าจุดอ้างอิงมีขนาดตรงกับความเป็นจริง (100 ซม.)\n• ป้อนข้อมูลสายพันธุ์ เพศ และอายุที่ถูกต้อง\n• ใช้การวัดด้วยตนเองเพื่อความแม่นยำสูงสุด',
                style: TextStyle(color: Colors.amber[800]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideStep({
    required int number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDarkColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}