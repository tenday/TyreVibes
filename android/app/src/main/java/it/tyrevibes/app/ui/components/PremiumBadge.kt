package it.tyrevibes.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.ui.theme.SoraFontFamily

enum class BadgeSize {
    SMALL, MEDIUM, LARGE;

    val iconSize: Int
        get() = when (this) {
            SMALL -> 12
            MEDIUM -> 16
            LARGE -> 20
        }

    val fontSize: Int
        get() = when (this) {
            SMALL -> 10
            MEDIUM -> 14
            LARGE -> 16
        }

    val horizontalPadding: Int
        get() = when (this) {
            SMALL -> 8
            MEDIUM -> 12
            LARGE -> 16
        }

    val verticalPadding: Int
        get() = when (this) {
            SMALL -> 4
            MEDIUM -> 6
            LARGE -> 8
        }

    val cornerRadius: Int
        get() = when (this) {
            SMALL -> 8
            MEDIUM -> 10
            LARGE -> 12
        }

    val spacing: Int
        get() = when (this) {
            SMALL -> 4
            MEDIUM -> 6
            LARGE -> 8
        }
}

/**
 * Premium Badge - Indica lo stato Premium dell'utente
 */
@Composable
fun PremiumBadge(
    modifier: Modifier = Modifier,
    size: BadgeSize = BadgeSize.MEDIUM,
    showLabel: Boolean = true
) {
    Row(
        modifier = modifier
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFFFFD700).copy(alpha = 0.3f),
                        Color(0xFFFF8C00).copy(alpha = 0.3f)
                    ),
                    start = Offset.Zero,
                    end = Offset.Infinite
                ),
                shape = RoundedCornerShape(size.cornerRadius.dp)
            )
            .border(
                width = 1.dp,
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFFFFD700),
                        Color(0xFFFF8C00)
                    )
                ),
                shape = RoundedCornerShape(size.cornerRadius.dp)
            )
            .padding(
                horizontal = size.horizontalPadding.dp,
                vertical = size.verticalPadding.dp
            ),
        horizontalArrangement = Arrangement.spacedBy(size.spacing.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Star,
            contentDescription = "Premium",
            tint = Color(0xFFFFD700),
            modifier = Modifier.size(size.iconSize.dp)
        )

        if (showLabel) {
            Text(
                text = "Premium",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = size.fontSize.sp,
                color = Color.White
            )
        }
    }
}

/**
 * Locked Feature Badge - Badge per funzionalità bloccate
 */
@Composable
fun LockedFeatureBadge(
    modifier: Modifier = Modifier,
    size: BadgeSize = BadgeSize.MEDIUM,
    showLabel: Boolean = true
) {
    Row(
        modifier = modifier
            .background(
                color = Color.White.copy(alpha = 0.1f),
                shape = RoundedCornerShape(size.cornerRadius.dp)
            )
            .border(
                width = 1.dp,
                color = Color(0xFFFFD700).copy(alpha = 0.5f),
                shape = RoundedCornerShape(size.cornerRadius.dp)
            )
            .padding(
                horizontal = size.horizontalPadding.dp,
                vertical = size.verticalPadding.dp
            ),
        horizontalArrangement = Arrangement.spacedBy(size.spacing.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Lock,
            contentDescription = "Locked",
            tint = Color(0xFFFFD700),
            modifier = Modifier.size(size.iconSize.dp)
        )

        if (showLabel) {
            Text(
                text = "Premium",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = size.fontSize.sp,
                color = Color.White.copy(alpha = 0.8f)
            )
        }
    }
}

/**
 * Limit Reached Badge - Mostra il limite raggiunto
 */
@Composable
fun LimitReachedBadge(
    current: Int,
    max: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .background(
                color = Color(0xFFFF8C00).copy(alpha = 0.2f),
                shape = RoundedCornerShape(8.dp)
            )
            .border(
                width = 1.dp,
                color = Color(0xFFFF8C00).copy(alpha = 0.5f),
                shape = RoundedCornerShape(8.dp)
            )
            .padding(horizontal = 10.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = "Limit reached",
            tint = Color(0xFFFF8C00),
            modifier = Modifier.size(12.dp)
        )

        Text(
            text = "$current/$max",
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            color = Color.White
        )
    }
}
