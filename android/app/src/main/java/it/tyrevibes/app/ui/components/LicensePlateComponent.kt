package it.tyrevibes.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.ui.theme.SoraFontFamily

/**
 * License Plate Component - Targa italiana stilizzata
 */
@Composable
fun LicensePlateComponent(
    text: String,
    countryCode: String = "I",
    modifier: Modifier = Modifier,
    width: Int = 200,
    height: Int = 100
) {
    val plateWidth = width.dp
    val plateHeight = height.dp
    val cornerRadius = plateHeight * 0.18f
    val blueWidth = plateHeight * 0.28f

    Box(
        modifier = modifier
            .width(plateWidth)
            .height(plateHeight)
            .shadow(4.dp, RoundedCornerShape(cornerRadius))
            .clip(RoundedCornerShape(cornerRadius))
            .background(Color.White)
            .border(3.dp, Color.Black, RoundedCornerShape(cornerRadius))
    ) {
        // Blue EU band on the left
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .width(blueWidth)
                .background(Color(0xFF0059B3))
                .align(Alignment.CenterStart),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = countryCode,
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = (plateHeight.value * 0.38f).sp,
                color = Color.White
            )
        }

        // Plate number text
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = blueWidth + 8.dp, end = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = text,
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = (plateHeight.value * 0.5f).sp,
                color = Color.Gray.copy(alpha = 0.8f)
            )
        }

        // Rivets (simulated screws)
        Box(
            modifier = Modifier
                .size((plateHeight.value * 0.08f).dp)
                .offset(x = plateWidth * 0.14f, y = plateHeight * 0.22f)
                .clip(CircleShape)
                .background(Color.Gray.copy(alpha = 0.6f))
                .border(1.dp, Color.Black.copy(alpha = 0.3f), CircleShape)
        )

        Box(
            modifier = Modifier
                .size((plateHeight.value * 0.08f).dp)
                .offset(x = plateWidth * 0.86f, y = plateHeight * 0.22f)
                .clip(CircleShape)
                .background(Color.Gray.copy(alpha = 0.6f))
                .border(1.dp, Color.Black.copy(alpha = 0.3f), CircleShape)
        )
    }
}
