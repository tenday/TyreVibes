package it.tyrevibes.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = PrimaryBlue,
    onPrimary = TextOnPrimary,
    primaryContainer = PrimaryBlueLight,
    onPrimaryContainer = TextPrimary,
    secondary = SecondaryOrange,
    onSecondary = TextOnPrimary,
    secondaryContainer = SecondaryOrangeLight,
    onSecondaryContainer = TextPrimary,
    tertiary = AccentPurple,
    onTertiary = TextOnPrimary,
    error = StatusError,
    onError = TextOnPrimary,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = BackgroundLight,
    onBackground = TextPrimary,
    surface = SurfaceLight,
    onSurface = TextPrimary,
    surfaceVariant = Gray200,
    onSurfaceVariant = TextSecondary,
    outline = Gray400
)

private val DarkColorScheme = darkColorScheme(
    primary = PrimaryBlueLight,
    onPrimary = Color(0xFF003258),
    primaryContainer = PrimaryBlueDark,
    onPrimaryContainer = Color(0xFFBBE1FF),
    secondary = SecondaryOrangeLight,
    onSecondary = Color(0xFF4A2800),
    secondaryContainer = SecondaryOrangeDark,
    onSecondaryContainer = Color(0xFFFFDDB3),
    tertiary = Color(0xFFBEB6FF),
    onTertiary = Color(0xFF2B2865),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = BackgroundDark,
    onBackground = Color(0xFFE3E2E6),
    surface = SurfaceDark,
    onSurface = Color(0xFFE3E2E6),
    surfaceVariant = Gray700,
    onSurfaceVariant = Gray400,
    outline = Gray500
)

@Composable
fun TyreVibesTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
