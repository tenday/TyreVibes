package it.tyrevibes.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Vehicle(
    val id: Int,
    @SerialName("model_detail") val modelDetail: String? = null,
    val engine: String? = null,
    val make: String? = null,
    val model: String? = null,
    val version: String? = null,
    @SerialName("fuel_type") val fuelType: String? = null,
    @SerialName("displacement_cc") val displacementCC: Int? = null,
    @SerialName("power_cv") val powerCV: Int? = null,
    @SerialName("power_kw") val powerKW: String? = null,
    @SerialName("emission_class") val emissionClass: String? = null,
    val gearbox: String? = null,
    @SerialName("max_speed") val maxSpeed: String? = null,
    @SerialName("body_type") val bodyType: String? = null,
    val doors: String? = null,
    val seats: String? = null,
    val consumption: String? = null,
    val traction: String? = null,
    @SerialName("sale_start") val saleStart: String? = null,
    @SerialName("sale_end") val saleEnd: String? = null,
    val color: String? = null,
    val vin: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class Plate(
    val id: Int,
    @SerialName("plate_number") val plateNumber: String,
    @SerialName("registration_date") val registrationDate: String? = null,
    val year: Int? = null,
    val month: Int? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class VehicleImage(
    val id: Int,
    @SerialName("mime_type") val mimeType: String? = null,
    val color: String? = null,
    @SerialName("file_name") val fileName: String? = null,
    @SerialName("file_size") val fileSize: Int? = null,
    val sha256: String? = null,
    @SerialName("image_base64") val imageBase64: String? = null
)

@Serializable
data class VehicleTyre(
    val id: Int,
    val width: Int? = null,
    val diameter: Int? = null,
    val ratio: Int? = null,
    @SerialName("speed_index") val speedIndex: String? = null,
    @SerialName("load_index") val loadIndex: String? = null,
    @SerialName("size_label") val sizeLabel: String? = null,
    @SerialName("set_id") val setId: Int? = null,
    @SerialName("set_name") val setName: String? = null
)

@Serializable
data class VehicleRevision(
    val id: Int,
    @SerialName("plate_id") val plateId: Int,
    val kmRevisione: String? = null,
    val dataRevisione: String? = null,
    val esitoRevisione: String? = null
)

@Serializable
data class VehicleInsurance(
    val id: Int,
    @SerialName("plate_id") val plateId: Int,
    @SerialName("rca_company") val rcaCompany: String? = null,
    @SerialName("rca_policy_number") val rcaPolicyNumber: String? = null,
    @SerialName("rca_expiry") val rcaExpiry: String? = null,
    @SerialName("rca_insurance_present") val rcaInsurancePresent: Int? = null
)

// MARK: - Tyre Size Set
data class TyreSizeSet(
    val id: Int,
    val name: String,
    val tyres: List<VehicleTyre>,
    val isDefault: Boolean = false
)
