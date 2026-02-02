import Foundation

/// Scale mode for image requests
public enum ImageScale: String, Sendable {
    /// Scale to fit within dimensions, maintaining aspect ratio
    case fit
    /// Scale to fill dimensions, cropping if needed
    case fill
    /// Stretch to exact dimensions, ignoring aspect ratio
    case stretch
}

/// Image format for requests
public enum ImageFormat: String, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
}

/// Options for image requests
public struct ImageOptions: Sendable {
    /// Scale mode (if set, width and height are required)
    public let scale: ImageScale?
    /// Width in pixels (required if scale is set)
    public let width: Int?
    /// Height in pixels (required if scale is set)
    public let height: Int?
    /// Preferred image format (Roon chooses if not specified)
    public let format: ImageFormat?

    public init(
        scale: ImageScale? = nil,
        width: Int? = nil,
        height: Int? = nil,
        format: ImageFormat? = nil
    ) {
        self.scale = scale
        self.width = width
        self.height = height
        self.format = format
    }

    /// Create options for a scaled image
    public static func scaled(_ scale: ImageScale, width: Int, height: Int, format: ImageFormat? = nil) -> ImageOptions {
        ImageOptions(scale: scale, width: width, height: height, format: format)
    }

    /// Create options for original size image
    public static var original: ImageOptions {
        ImageOptions()
    }
}

/// Result of an image request
public struct ImageResult: Sendable {
    /// The image data
    public let data: Data
    /// The MIME content type (e.g., "image/jpeg", "image/png")
    public let contentType: String

    public init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}

/// Errors from image service operations
public enum ImageError: Error, Sendable {
    case invalidImageKey
    case missingScaleDimensions
    case networkError(String)
    case invalidResponse
    case httpError(Int)
}

extension ImageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidImageKey:
            return "invalid image key"
        case .missingScaleDimensions:
            return "width and height are required when scale is set"
        case .networkError(let message):
            return "network error: \(message)"
        case .invalidResponse:
            return "invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

/// Service for fetching images from Roon
public actor ImageService {
    private let host: String
    private let port: Int
    private let urlSession: URLSession

    /// Create an image service
    /// - Parameters:
    ///   - host: Roon Core host
    ///   - port: Roon Core HTTP port
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
        self.urlSession = URLSession.shared
    }

    /// Fetch an image by its key
    /// - Parameters:
    ///   - imageKey: The image key from Roon API (e.g., from now_playing.image_key)
    ///   - options: Optional scaling and format options
    /// - Returns: Image data and content type
    public func getImage(imageKey: String, options: ImageOptions = .original) async throws -> ImageResult {
        guard !imageKey.isEmpty else {
            throw ImageError.invalidImageKey
        }

        // Validate that if scale is set, dimensions are provided
        if options.scale != nil && (options.width == nil || options.height == nil) {
            throw ImageError.missingScaleDimensions
        }

        // Build URL with query parameters
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/api/image/\(imageKey)"

        var queryItems: [URLQueryItem] = []
        if let scale = options.scale {
            queryItems.append(URLQueryItem(name: "scale", value: scale.rawValue))
        }
        if let width = options.width {
            queryItems.append(URLQueryItem(name: "width", value: String(width)))
        }
        if let height = options.height {
            queryItems.append(URLQueryItem(name: "height", value: String(height)))
        }
        if let format = options.format {
            queryItems.append(URLQueryItem(name: "format", value: format.rawValue))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw ImageError.invalidImageKey
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ImageError.httpError(httpResponse.statusCode)
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "image/jpeg"

            return ImageResult(data: data, contentType: contentType)
        } catch let error as ImageError {
            throw error
        } catch {
            throw ImageError.networkError(error.localizedDescription)
        }
    }

    /// Build an image URL without fetching
    /// Useful for SwiftUI AsyncImage or other image loading frameworks
    /// - Parameters:
    ///   - imageKey: The image key from Roon API
    ///   - options: Optional scaling and format options
    /// - Returns: URL for the image
    public func imageURL(imageKey: String, options: ImageOptions = .original) -> URL? {
        guard !imageKey.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/api/image/\(imageKey)"

        var queryItems: [URLQueryItem] = []
        if let scale = options.scale {
            queryItems.append(URLQueryItem(name: "scale", value: scale.rawValue))
        }
        if let width = options.width {
            queryItems.append(URLQueryItem(name: "width", value: String(width)))
        }
        if let height = options.height {
            queryItems.append(URLQueryItem(name: "height", value: String(height)))
        }
        if let format = options.format {
            queryItems.append(URLQueryItem(name: "format", value: format.rawValue))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url
    }
}
