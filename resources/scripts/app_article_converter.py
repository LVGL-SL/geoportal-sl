import sys
import argparse
import logging
from pathlib import Path

# Add parent directory to path to import from useroperations
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from useroperations.utils.app_article_json_conv_class import JsonConverter

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(
        description='Convert article JSON files from V1/V2 to V3 format',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        'path',
        nargs='?',
        default=None,
        help='Path to a JSON file or folder containing JSON files'
    )
    
    args = parser.parse_args()
    
    if args.path is None:
        logger.error("Error: path argument is required")
        sys.exit(1)
    
    path = Path(args.path)
    
    if not path.exists():
        logger.error(f"Error: Path does not exist: {args.path}")
        sys.exit(1)
    
    try:
        converter = JsonConverter()
        
        if path.is_file():
            # Single file
            if not converter.convert_file(path):
                logger.error(f"Failed to convert file: {path}")
                sys.exit(1)
            logger.info(f"Successfully converted: {path}")
        elif path.is_dir():
            # Directory of files
            converter.convert_all_files(path)
        else:
            try:
                # Converter can work on its default directory when class init is changed
                converter.convert_all_files()
            except Exception as e:
                logger.error(f"Error: {str(e)}")
                sys.exit(1)
    except ValueError as e:
        logger.error(f"Error: {str(e)}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()